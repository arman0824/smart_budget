import SwiftUI
import SwiftData

struct SubscriptionFormView: View {
    @EnvironmentObject private var appStore: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BudgetCategory.sortOrder) private var categories: [BudgetCategory]

    private let subscription: Subscription?
    @State private var name: String
    @State private var merchant: String
    @State private var amountText: String
    @State private var currencyCode: String
    @State private var billingCycle: SubscriptionBillingCycle
    @State private var hasNextBillingDate: Bool
    @State private var nextBillingDate: Date
    @State private var categoryID: UUID?
    @State private var status: SubscriptionStatus
    @State private var trialEndDate: Date
    @State private var hasTrialEndDate: Bool
    @State private var reminderDaysBefore: Int
    @State private var notes: String
    @State private var website: String
    @State private var validationMessage: String?
    @State private var showDeleteConfirmation = false

    private let currencies = ["INR", "USD", "EUR", "GBP", "AUD", "CAD", "SGD", "JPY"]

    init(subscription: Subscription? = nil) {
        self.subscription = subscription
        _name = State(initialValue: subscription?.name ?? "")
        _merchant = State(initialValue: subscription?.merchant ?? "")
        _amountText = State(initialValue: subscription.map { NSDecimalNumber(decimal: $0.amount).stringValue } ?? "")
        _currencyCode = State(initialValue: subscription?.currencyCode ?? "INR")
        _billingCycle = State(initialValue: subscription?.billingCycle ?? .monthly)
        _hasNextBillingDate = State(initialValue: subscription?.nextBillingDate != nil)
        _nextBillingDate = State(initialValue: subscription?.nextBillingDate ?? Date())
        _categoryID = State(initialValue: subscription?.categoryID)
        _status = State(initialValue: subscription?.status ?? .active)
        _trialEndDate = State(initialValue: subscription?.trialEndDate ?? Date())
        _hasTrialEndDate = State(initialValue: subscription?.trialEndDate != nil)
        _reminderDaysBefore = State(initialValue: subscription?.reminderDaysBefore ?? 3)
        _notes = State(initialValue: subscription?.notes ?? "")
        _website = State(initialValue: subscription?.website ?? "")
    }

    private var visibleCategories: [BudgetCategory] { categories.filter { !$0.isArchived } }
    private var amount: Decimal { Decimal(string: amountText.replacingOccurrences(of: ",", with: "")) ?? .zero }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isValid: Bool {
        guard !trimmedName.isEmpty, amount > .zero else { return false }
        guard hasNextBillingDate else { return true }
        guard let earliestDate = Calendar.current.date(byAdding: .year, value: -20, to: Date()) else { return true }
        return nextBillingDate >= earliestDate
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Service name", text: $name)
                        .platformWordsAutocapitalization()
                    TextField("Merchant (optional)", text: $merchant)
                        .platformWordsAutocapitalization()
                    HStack {
                        Text(currencyCode)
                            .font(.headline)
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                        TextField("Price", text: $amountText)
                            .platformDecimalKeyboard()
                            .multilineTextAlignment(.trailing)
                            .font(.title3.monospacedDigit().weight(.semibold))
                    }
                    Picker("Billing currency", selection: $currencyCode) {
                        ForEach(currencies, id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }
                    Picker("Billing cycle", selection: $billingCycle) {
                        ForEach(SubscriptionBillingCycle.allCases, id: \.self) { cycle in
                            Text(cycle.displayName).tag(cycle)
                        }
                    }
                } header: {
                    Text("Subscription")
                } footer: {
                    if let validationMessage {
                        Text(validationMessage).foregroundStyle(DesignSystem.Colors.danger)
                    }
                }

                Section("Renewal") {
                    Toggle("Has a next billing date", isOn: $hasNextBillingDate)
                    if hasNextBillingDate {
                        DatePicker("Next billing date", selection: $nextBillingDate, displayedComponents: .date)
                    }
                    Picker("Status", selection: $status) {
                        ForEach(SubscriptionStatus.allCases, id: \.self) { value in
                            Text(value.displayName).tag(value)
                        }
                    }
                    if status == .trial {
                        Toggle("Has a trial end date", isOn: $hasTrialEndDate)
                        if hasTrialEndDate {
                            DatePicker("Trial ends", selection: $trialEndDate, displayedComponents: .date)
                        }
                    }
                }

                Section("Organization") {
                    Picker("Category", selection: $categoryID) {
                        Text("Uncategorized").tag(Optional<UUID>.none)
                        ForEach(visibleCategories, id: \.id) { category in
                            Label(category.name, systemImage: category.iconName)
                                .tag(Optional(category.id))
                        }
                    }
                    TextField("Website (optional)", text: $website)
                        .platformURLKeyboard()
                        .platformNoAutocapitalization()
                }

                Section {
                    Picker("Remind me", selection: $reminderDaysBefore) {
                        Text("Never").tag(0)
                        Text("1 day before").tag(1)
                        Text("3 days before").tag(3)
                        Text("7 days before").tag(7)
                    }
                    TextField("Renewal notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                } header: {
                    Text("Reminder")
                } footer: {
                    Text("A reminder is scheduled only for active or trial subscriptions with a future billing date. iOS notification permission is required.")
                }

                if subscription != nil {
                    Section {
                        Button("Delete subscription", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(DesignSystem.Colors.background)
            .navigationTitle(subscription == nil ? "Add subscription" : "Edit subscription")
            .platformInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                        .fontWeight(.semibold)
                }
            }
            .onChange(of: status) { _, newStatus in
                if newStatus != .trial {
                    hasTrialEndDate = false
                }
            }
            .confirmationDialog("Delete this subscription?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let subscription {
                        appStore.deleteSubscription(subscription)
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func save() {
        guard isValid else {
            validationMessage = "Add a service name and a price greater than zero."
            return
        }

        let trimmedMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        if let subscription {
            subscription.name = trimmedName
            subscription.merchant = trimmedMerchant
            subscription.amount = amount
            subscription.currencyCode = currencyCode
            subscription.billingCycle = billingCycle
            subscription.nextBillingDate = hasNextBillingDate ? nextBillingDate : nil
            subscription.categoryID = categoryID
            subscription.status = status
            subscription.trialEndDate = status == .trial && hasTrialEndDate ? trialEndDate : nil
            subscription.reminderDaysBefore = reminderDaysBefore
            subscription.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            subscription.website = website.trimmingCharacters(in: .whitespacesAndNewlines)
            subscription.updatedAt = Date()
        } else {
            let newSubscription = Subscription(
                name: trimmedName,
                merchant: trimmedMerchant,
                amount: amount,
                currencyCode: currencyCode,
                billingCycle: billingCycle,
                nextBillingDate: hasNextBillingDate ? nextBillingDate : nil,
                categoryID: categoryID,
                status: status,
                trialEndDate: status == .trial && hasTrialEndDate ? trialEndDate : nil,
                reminderDaysBefore: reminderDaysBefore,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                website: website.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            modelContext.insert(newSubscription)
            if appStore.save() {
                appStore.scheduleReminder(for: newSubscription)
                dismiss()
            }
            return
        }

        if appStore.save() {
            if let subscription {
                appStore.scheduleReminder(for: subscription)
            }
            dismiss()
        }
    }
}
