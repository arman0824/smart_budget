import Foundation
import SwiftData

@Model
public final class AppPreferences {
    @Attribute(.unique) public var id: UUID
    public var currencyCode: String
    public var localeIdentifier: String
    public var notificationsEnabled: Bool
    public var reminderDaysBefore: Int
    public var reminderHour: Int
    public var reminderMinute: Int
    public var hasCompletedOnboarding: Bool

    public init(
        id: UUID = UUID(),
        currencyCode: String = "INR",
        localeIdentifier: String = "en_IN",
        notificationsEnabled: Bool = true,
        reminderDaysBefore: Int = 3,
        reminderHour: Int = 9,
        reminderMinute: Int = 0,
        hasCompletedOnboarding: Bool = false,
        monthlySpendingAllowance: Decimal = .zero,
        monthlyIncomeTarget: Decimal = .zero,
        monthlySavingsGoal: Decimal = .zero,
        hasSampleData: Bool = false
    ) {
        self.id = id
        self.currencyCode = currencyCode
        self.localeIdentifier = localeIdentifier
        self.notificationsEnabled = notificationsEnabled
        self.reminderDaysBefore = max(0, reminderDaysBefore)
        self.reminderHour = min(max(0, reminderHour), 23)
        self.reminderMinute = min(max(0, reminderMinute), 59)
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.monthlySpendingAllowance = monthlySpendingAllowance < Decimal.zero ? -monthlySpendingAllowance : monthlySpendingAllowance
        self.monthlyIncomeTarget = monthlyIncomeTarget < Decimal.zero ? -monthlyIncomeTarget : monthlyIncomeTarget
        self.monthlySavingsGoal = monthlySavingsGoal < Decimal.zero ? -monthlySavingsGoal : monthlySavingsGoal
        self.hasSampleData = hasSampleData
    }

    public var monthlySpendingAllowance: Decimal
    public var monthlyIncomeTarget: Decimal
    public var monthlySavingsGoal: Decimal
    public var hasSampleData: Bool
}
