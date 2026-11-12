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
    /// Published so currency, locale, allowance, and reminder changes refresh
    /// every view and `MoneyText` immediately.
    @Published private(set) var preferences: AppPreferences?

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

        preferences = (try? modelContext.fetch(FetchDescriptor<AppPreferences>()))?.first
    }

    /// Locale used for amount entry and display. Derived from the selected
    /// currency so `1.234,56` and `1,234.56` are both understood correctly.
    var displayLocale: Locale {
        guard let preferences, !preferences.localeIdentifier.isEmpty else { return .current }
        return Locale(identifier: preferences.localeIdentifier)
    }

    /// Re-reads the preferences row and publishes it. Called after every save
    /// that can touch preferences so dependent views stay in sync.
    private func refreshPreferences() {
        guard let current = (try? modelContext.fetch(FetchDescriptor<AppPreferences>()))?.first else { return }
        // Assign unconditionally: @Published notifies even when the reference is
        // unchanged, which is what refreshes views after in-place mutations.
        preferences = current
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
            refreshPreferences()
            return true
        } catch {
            lastError = "We couldn't save that change. Your existing data is still safe."
            return false
        }
    }

    /// Creates and persists a new transaction after applying the same input
    /// rules used by transaction entry views. A nil result means the draft was
    /// invalid or the context could not be saved.
    @discardableResult
    func recordTransaction(
        date: Date = Date(),
        amount: Decimal,
        merchant: String,
        note: String = "",
        paymentMethod: String = "",
        categoryID: UUID? = nil,
        linkedSubscriptionID: UUID? = nil,
        kind: TransactionKind = .expense,
        isSampleData: Bool = false
    ) -> Transaction? {
        let trimmedMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        guard amount > .zero, !trimmedMerchant.isEmpty else { return nil }

        let transaction = Transaction(
            date: date,
            amount: amount,
            merchant: trimmedMerchant,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            paymentMethod: paymentMethod.trimmingCharacters(in: .whitespacesAndNewlines),
            categoryID: kind == .expense || kind == .refund ? categoryID : nil,
            linkedSubscriptionID: linkedSubscriptionID,
            kind: kind,
            isSampleData: isSampleData
        )
        modelContext.insert(transaction)

        return save() ? transaction : nil
    }

    func clearError() {
        guard lastError != nil else { return }
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

        let wantsReminders = preferences.notificationsEnabled
        _ = save()

        if wantsReminders {
            scheduleAllReminders()
        } else {
            notificationService.cancelReminders(for: fetchSubscriptions())
        }
    }

    func makePreferences() -> AppPreferences {
        let newPreferences = AppPreferences()
        modelContext.insert(newPreferences)
        preferences = newPreferences
        return newPreferences
    }

    /// Case-insensitive duplicate check used by the category editor. Duplicate
    /// names would otherwise crash sample-data seeding and confuse pickers.
    func categoryNameExists(_ name: String, excluding categoryID: UUID? = nil) -> Bool {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return false }
        let all = (try? modelContext.fetch(FetchDescriptor<BudgetCategory>())) ?? []
        return all.contains { category in
            if let categoryID, category.id == categoryID { return false }
            return category.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized
        }
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

    func restoreCategory(_ category: BudgetCategory) {
        guard category.isArchived else { return }
        category.isArchived = false
        category.sortOrder = (categories.map(\.sortOrder).max() ?? -1) + 1
        _ = save()
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
        let categoryIDs = Dictionary(
            availableCategories.map { ($0.name, $0.id) },
            uniquingKeysWith: { first, _ in first }
        )
        let today = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? today
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: today) ?? today
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: today) ?? today

        // Sample amounts are written for INR. Scale them into the currency the
        // user chose during onboarding so a US or European user does not see a
        // $60,000 salary alongside $180 rent.
        let currencyCode = preferences?.currencyCode ?? "INR"
        let scale: Decimal
        switch currencyCode.uppercased() {
        case "JPY": scale = 2
        case "INR": scale = 1
        default: scale = Decimal(0.025)
        }
        func sampleAmount(_ value: Decimal) -> Decimal { value * scale }

        let sampleTransactions = [
            Transaction(date: twoWeeksAgo, amount: sampleAmount(Decimal(7200)), merchant: "Apartment rent", note: "Monthly home payment", categoryID: categoryIDs["Housing"], kind: .expense, isSampleData: true),
            Transaction(date: weekAgo, amount: sampleAmount(Decimal(1850)), merchant: "Fresh Market", note: "Weekly groceries", categoryID: categoryIDs["Groceries"], kind: .expense, isSampleData: true),
            Transaction(date: calendar.date(byAdding: .day, value: -3, to: today) ?? today, amount: sampleAmount(Decimal(920)), merchant: "The Green Table", note: "Dinner with friends", categoryID: categoryIDs["Dining"], kind: .expense, isSampleData: true),
            Transaction(date: calendar.date(byAdding: .day, value: -4, to: today) ?? today, amount: sampleAmount(Decimal(60000)), merchant: "Salary", note: "Monthly income", categoryID: nil, kind: .income, isSampleData: true),
            Transaction(date: calendar.date(byAdding: .day, value: -1, to: today) ?? today, amount: sampleAmount(Decimal(680)), merchant: "Metro card", note: "Commute", categoryID: categoryIDs["Transport"], kind: .expense, isSampleData: true),
            Transaction(date: lastMonth, amount: sampleAmount(Decimal(1200)), merchant: "Fresh Market", note: "Last month's groceries", categoryID: categoryIDs["Groceries"], kind: .expense, isSampleData: true)
        ]
        sampleTransactions.forEach(modelContext.insert)

        let upcomingWeek = calendar.date(byAdding: .day, value: 7, to: today)
        let upcomingMonth = calendar.date(byAdding: .day, value: 18, to: today)
        let subscriptions = [
            Subscription(name: "Streamline", merchant: "Streamline", amount: sampleAmount(Decimal(899)), currencyCode: currencyCode, billingCycle: .monthly, nextBillingDate: upcomingWeek, categoryID: categoryIDs["Entertainment"], status: .active, reminderDaysBefore: 3, notes: "Family plan", isSampleData: true),
            Subscription(name: "CloudBox", merchant: "CloudBox", amount: sampleAmount(Decimal(4999)), currencyCode: currencyCode, billingCycle: .yearly, nextBillingDate: upcomingMonth, categoryID: categoryIDs["Bills & utilities"], status: .active, reminderDaysBefore: 7, notes: "Annual storage renewal", isSampleData: true),
            Subscription(name: "Focus Pro", merchant: "Focus Pro", amount: sampleAmount(Decimal(599)), currencyCode: currencyCode, billingCycle: .monthly, nextBillingDate: upcomingMonth, categoryID: categoryIDs["Education"], status: .trial, trialEndDate: upcomingMonth, reminderDaysBefore: 3, notes: "Trial ends soon", isSampleData: true)
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
                modelContext.insert(BudgetPlan(monthStart: monthStart(for: today), categoryID: categoryID, limit: sampleAmount(limit), isSampleData: true))
            }
        }

        _ = save()
    }

    private func normalized(_ value: Decimal) -> Decimal {
        value < Decimal.zero ? -value : value
    }
}
