import Foundation
import UserNotifications

@MainActor
public final class SubscriptionNotificationService {
    private let center: UNUserNotificationCenter
    private let calendar: Calendar

    public init(
        center: UNUserNotificationCenter = .current(),
        calendar: Calendar = .current
    ) {
        self.center = center
        self.calendar = calendar
    }

    public static func notificationIdentifier(for subscriptionID: UUID) -> String {
        "subscription-reminder-\(subscriptionID.uuidString)"
    }

    /// Cancelled and paused subscriptions never receive reminders. Calling
    /// this method is idempotent, so a stale or already-delivered request is
    /// safe to remove whenever a subscription changes state.
    public func cancelReminder(for subscriptionID: UUID) {
        let identifier = Self.notificationIdentifier(for: subscriptionID)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    public func cancelReminder(for subscription: Subscription) {
        cancelReminder(for: subscription.id)
    }

    public func cancelReminders(for subscriptions: [Subscription]) {
        subscriptions.forEach { cancelReminder(for: $0.id) }
    }

    /// Requests notification permission only as part of a real schedule
    /// operation. A denied permission or disabled preference returns false and
    /// leaves no pending request behind.
    public func scheduleReminder(
        for subscription: Subscription,
        preferences: AppPreferences? = nil,
        now: Date = Date()
    ) async throws -> Bool {
        guard subscription.status.canHaveUpcomingPayment else {
            cancelReminder(for: subscription.id)
            return false
        }

        guard preferences?.notificationsEnabled ?? true else {
            cancelReminder(for: subscription.id)
            return false
        }

        guard subscription.reminderDaysBefore > 0 else {
            cancelReminder(for: subscription.id)
            return false
        }

        guard let reminderDate = reminderDate(
            for: subscription,
            preferences: preferences,
            now: now
        ) else {
            cancelReminder(for: subscription.id)
            return false
        }

        let authorizationGranted = try await center.requestAuthorization(options: [.alert, .sound])
        guard authorizationGranted else {
            cancelReminder(for: subscription.id)
            return false
        }

        let content = UNMutableNotificationContent()
        let displayName = subscription.name.trimmingCharacters(in: .whitespacesAndNewlines)
        content.title = displayName.isEmpty ? "Subscription reminder" : displayName
        content.body = "Your subscription payment is scheduled soon."
        content.sound = .default

        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminderDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.notificationIdentifier(for: subscription.id),
            content: content,
            trigger: trigger
        )

        cancelReminder(for: subscription.id)
        try await center.add(request)
        return true
    }

    public func scheduleReminders(
        for subscriptions: [Subscription],
        preferences: AppPreferences? = nil,
        now: Date = Date()
    ) async throws -> [UUID] {
        var scheduledIDs: [UUID] = []

        for subscription in subscriptions {
            if try await scheduleReminder(
                for: subscription,
                preferences: preferences,
                now: now
            ) {
                scheduledIDs.append(subscription.id)
            }
        }

        return scheduledIDs
    }

    private func reminderDate(
        for subscription: Subscription,
        preferences: AppPreferences?,
        now: Date
    ) -> Date? {
        guard let originalBillingDate = subscription.nextBillingDate else {
            return nil
        }

        var billingDate = originalBillingDate
        let reminderDays = max(0, subscription.reminderDaysBefore)

        // A bounded loop handles dates that have been left in the past while
        // keeping malformed calendar data from causing an unbounded search.
        for _ in 0..<10_000 {
            guard let date = calendar.date(
                byAdding: .day,
                value: -reminderDays,
                to: billingDate
            ) else {
                return nil
            }

            let reminderDate = applyingPreferredTime(
                to: date,
                preferences: preferences
            )

            if let reminderDate, reminderDate > now {
                return reminderDate
            }

            guard let nextBillingDate = FinancialCalculator.advance(
                date: billingDate,
                by: subscription.billingCycle,
                calendar: calendar
            ) else {
                return nil
            }
            billingDate = nextBillingDate
        }

        return nil
    }

    private func applyingPreferredTime(
        to date: Date,
        preferences: AppPreferences?
    ) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        let existingTime = calendar.dateComponents([.hour, .minute], from: date)

        if let preferences {
            components.hour = min(max(preferences.reminderHour, 0), 23)
            components.minute = min(max(preferences.reminderMinute, 0), 59)
        } else {
            components.hour = existingTime.hour
            components.minute = existingTime.minute
        }
        components.second = 0

        return calendar.date(from: components)
    }
}
