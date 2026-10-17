import Combine
import Foundation
import SwiftData
import UserNotifications

enum AppTab: Hashable {
    case overview
    case activity
    case budgets
    case subscriptions
    case insights
}

@MainActor
final class AppStore: ObservableObject {
    let modelContext: ModelContext
    let calendar: Calendar
    let notificationService: SubscriptionNotificationService

    @Published var selectedMonth: Date
    @Published var selectedTab: AppTab = .overview
    @Published var lastError: String?

    init(
        modelContext: ModelContext,
        calendar: Calendar = .current,
        notificationService: SubscriptionNotificationService? = nil
    ) {
        self.modelContext = modelContext
        self.calendar = calendar
        self.notificationService = notificationService ?? SubscriptionNotificationService(calendar: calendar)
        self.selectedMonth = Date()

        do {
            try ModelContainerFactory.seedDefaults(in: modelContext)
        } catch {
            lastError = "Your local data could not be prepared. Please try again."
        }
    }

    var preferences: AppPreferences? {
        (try? modelContext.fetch(FetchDescriptor<AppPreferences>()))?.first
    }

    var categories: [BudgetCategory] {
        (try? modelContext.fetch(FetchDescriptor<BudgetCategory>()))?
            .filter { !$0.isArchived }
            .sorted { $0.sortOrder == $1.sortOrder ? $0.name < $1.name : $0.sortOrder < $1.sortOrder } ?? []
    }

    func fetchTransactions() -> [Transaction] {
        (try? modelContext.fetch(FetchDescriptor<Transaction>())) ?? []
    }

    func fetchSubscriptions() -> [Subscription] {
        (try? modelContext.fetch(FetchDescriptor<Subscription>())) ?? []
    }

    func fetchBudgetPlans() -> [BudgetPlan] {
        (try? modelContext.fetch(FetchDescriptor<BudgetPlan>())) ?? []
    }

    @discardableResult
    func save() -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            lastError = "We couldn't save that change. Your existing data is still safe."
            return false
        }
    }

    func clearError() {
        lastError = nil
    }

    func locale(for currencyCode: String) -> Locale {
        switch currencyCode.uppercased() {
        case "INR": return Locale(identifier: "en_IN")
        case "USD": return Locale(identifier: "en_US")
        case "EUR": return Locale(identifier: "de_DE")
        case "GBP": return Locale(identifier: "en_GB")
        case "JPY": return Locale(identifier: "ja_JP")
        case "AUD": return Locale(identifier: "en_AU")
        case "CAD": return Locale(identifier: "en_CA")
        case "SGD": return Locale(identifier: "en_SG")
        default: return Locale.current
        }
    }

    func completeOnboarding(
        currencyCode: String,
        monthlyAllowance: Decimal,
        incomeTarget: Decimal,
        savingsGoal: Decimal,
        useSampleData: Bool
    ) {
        let preferences = preferences ?? makePreferences()
        preferences.currencyCode = currencyCode.uppercased()
        preferences.localeIdentifier = locale(for: currencyCode).identifier
        preferences.monthlySpendingAllowance = normalized(monthlyAllowance)
        preferences.monthlyIncomeTarget = normalized(incomeTarget)
        preferences.monthlySavingsGoal = normalized(savingsGoal)
        preferences.hasCompletedOnboarding = true

        if useSampleData {
            seedSampleData()
            preferences.hasSampleData = true
        }

        _ = save()
    }

    func makePreferences() -> AppPreferences {
        let newPreferences = AppPreferences()
        modelContext.insert(newPreferences)
        return newPreferences
    }

    func updateCurrency(_ currencyCode: String) {
        let preferences = preferences ?? makePreferences()
        preferences.currencyCode = currencyCode.uppercased()
        preferences.localeIdentifier = locale(for: currencyCode).identifier
        _ = save()
    }

    @discardableResult
    func upsertBudgetPlan(
        for month: Date,
        categoryID: UUID,
        limit: Decimal,
        isSampleData: Bool = false
    ) -> BudgetPlan {
        let normalizedMonth = monthStart(for: month)
        let existing = fetchBudgetPlans().first {
            $0.categoryID == categoryID && calendar.isDate($0.monthStart, equalTo: normalizedMonth, toGranularity: .month)
        }

        if let existing {
            existing.limit = normalized(limit)
            existing.isSampleData = isSampleData
            _ = save()
            return existing
        }

        let plan = BudgetPlan(
            monthStart: normalizedMonth,
            categoryID: categoryID,
            limit: normalized(limit),
            isSampleData: isSampleData
        )
        modelContext.insert(plan)
        _ = save()
        return plan
    }

    func deleteBudgetPlan(_ plan: BudgetPlan) {
        modelContext.delete(plan)
        _ = save()
    }

    func deleteTransaction(_ transaction: Transaction) {
        modelContext.delete(transaction)
        _ = save()
    }

    func deleteSubscription(_ subscription: Subscription) {
        notificationService.cancelReminder(for: subscription)
        modelContext.delete(subscription)
        _ = save()
    }

    @discardableResult
    func deleteCategory(_ category: BudgetCategory) -> Bool {
        let hasTransactions = fetchTransactions().contains { $0.categoryID == category.id }
        guard !hasTransactions else {
            category.isArchived = true
            _ = save()
            return false
        }

        fetchBudgetPlans()
            .filter { $0.categoryID == category.id }
            .forEach(modelContext.delete)
        modelContext.delete(category)
        _ = save()
        return true
    }

    func scheduleReminder(for subscription: Subscription) {
        let currentPreferences = preferences
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                _ = try await notificationService.scheduleReminder(
                    for: subscription,
                    preferences: currentPreferences
                )
            } catch {
                lastError = "The reminder couldn't be scheduled. Check notification permissions in Settings."
            }
        }
    }

    func scheduleAllReminders() {
        let allSubscriptions = fetchSubscriptions()
        let currentPreferences = preferences
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                _ = try await notificationService.scheduleReminders(
                    for: allSubscriptions,
                    preferences: currentPreferences
                )
            } catch {
                lastError = "Some reminders couldn't be scheduled. Check notification permissions in Settings."
            }
        }
    }

    func requestNotificationPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func monthStart(for date: Date) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? date
    }

    func clearSampleData() {
        fetchTransactions().filter(\.isSampleData).forEach(modelContext.delete)
        fetchSubscriptions().filter(\.isSampleData).forEach {
            notificationService.cancelReminder(for: $0)
            modelContext.delete($0)
        }
        fetchBudgetPlans().filter(\.isSampleData).forEach(modelContext.delete)

        if let preferences {
            preferences.hasSampleData = false
        }
        _ = save()
    }

    func seedSampleData() {
        guard !fetchTransactions().contains(where: \.isSampleData) else { return }

        let availableCategories = categories
        let categoryIDs = Dictionary(uniqueKeysWithValues: availableCategories.map { ($0.name, $0.id) })
        let today = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? today
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: today) ?? today
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: today) ?? today

        let sampleTransactions = [
            Transaction(date: twoWeeksAgo, amount: Decimal(7200), merchant: "Apartment rent", note: "Monthly home payment", categoryID: categoryIDs["Housing"], kind: .expense, isSampleData: true),
            Transaction(date: weekAgo, amount: Decimal(1850), merchant: "Fresh Market", note: "Weekly groceries", categoryID: categoryIDs["Groceries"], kind: .expense, isSampleData: true),
            Transaction(date: calendar.date(byAdding: .day, value: -3, to: today) ?? today, amount: Decimal(920), merchant: "The Green Table", note: "Dinner with friends", categoryID: categoryIDs["Dining"], kind: .expense, isSampleData: true),
            Transaction(date: calendar.date(byAdding: .day, value: -4, to: today) ?? today, amount: Decimal(60000), merchant: "Salary", note: "Monthly income", categoryID: nil, kind: .income, isSampleData: true),
            Transaction(date: calendar.date(byAdding: .day, value: -1, to: today) ?? today, amount: Decimal(680), merchant: "Metro card", note: "Commute", categoryID: categoryIDs["Transport"], kind: .expense, isSampleData: true),
            Transaction(date: lastMonth, amount: Decimal(1200), merchant: "Fresh Market", note: "Last month's groceries", categoryID: categoryIDs["Groceries"], kind: .expense, isSampleData: true)
        ]
        sampleTransactions.forEach(modelContext.insert)

        let upcomingWeek = calendar.date(byAdding: .day, value: 7, to: today)
        let upcomingMonth = calendar.date(byAdding: .day, value: 18, to: today)
        let subscriptions = [
            Subscription(name: "Streamline", merchant: "Streamline", amount: Decimal(899), currencyCode: "INR", billingCycle: .monthly, nextBillingDate: upcomingWeek, categoryID: categoryIDs["Entertainment"], status: .active, reminderDaysBefore: 3, notes: "Family plan", isSampleData: true),
            Subscription(name: "CloudBox", merchant: "CloudBox", amount: Decimal(4999), currencyCode: "INR", billingCycle: .yearly, nextBillingDate: upcomingMonth, categoryID: categoryIDs["Bills & utilities"], status: .active, reminderDaysBefore: 7, notes: "Annual storage renewal", isSampleData: true),
            Subscription(name: "Focus Pro", merchant: "Focus Pro", amount: Decimal(599), currencyCode: "INR", billingCycle: .monthly, nextBillingDate: upcomingMonth, categoryID: categoryIDs["Education"], status: .trial, trialEndDate: upcomingMonth, reminderDaysBefore: 3, notes: "Trial ends soon", isSampleData: true)
        ]
        subscriptions.forEach(modelContext.insert)

        let planValues: [(String, Decimal)] = [
            ("Housing", Decimal(15000)),
            ("Groceries", Decimal(6500)),
            ("Dining", Decimal(3500)),
            ("Transport", Decimal(3000)),
            ("Entertainment", Decimal(2500))
        ]
        for (name, limit) in planValues {
            if let categoryID = categoryIDs[name] {
                modelContext.insert(BudgetPlan(monthStart: monthStart(for: today), categoryID: categoryID, limit: limit, isSampleData: true))
            }
        }

        _ = save()
    }

    private func normalized(_ value: Decimal) -> Decimal {
        value < Decimal.zero ? -value : value
    }
}
