import SwiftUI
import SwiftData

struct TransactionFormView: View {
    @EnvironmentObject private var appStore: AppStore
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \BudgetCategory.sortOrder) private var categories: [BudgetCategory]

    private let transaction: Transaction?
    private let subscriptionToRecord: Subscription?

    @State private var kind: TransactionKind
    @State private var amountText: String
    @State private var merchant: String
    @State private var categoryID: UUID?
    @State private var date: Date
    @State private var note: String
    @State private var paymentMethod: String
    @State private var linkedSubscriptionID: UUID?
    @State private var validationMessage: String?
    @State private var showDeleteConfirmation = false

    init(transaction: Transaction? = nil, subscriptionToRecord: Subscription? = nil) {
        self.transaction = transaction
        self.subscriptionToRecord = subscriptionToRecord
        _kind = State(initialValue: transaction?.kind ?? .expense)
        _amountText = State(initialValue: transaction.map { NSDecimalNumber(decimal: $0.normalizedAmount).stringValue } ?? subscriptionToRecord.map { NSDecimalNumber(decimal: $0.amount).stringValue } ?? "")
        _merchant = State(initialValue: transaction?.merchant ?? subscriptionToRecord?.merchant ?? subscriptionToRecord?.name ?? "")
        _categoryID = State(initialValue: transaction?.categoryID ?? subscriptionToRecord?.categoryID)
        _date = State(initialValue: transaction?.date ?? Date())
        _note = State(initialValue: transaction?.note ?? (subscriptionToRecord.map { "Recorded charge for \($0.name)" } ?? ""))
        _paymentMethod = State(initialValue: transaction?.paymentMethod ?? "")
        _linkedSubscriptionID = State(initialValue: transaction?.linkedSubscriptionID ?? subscriptionToRecord?.id)
    }

    private var visibleCategories: [BudgetCategory] {
        categories.filter { !$0.isArchived }.sorted {
            $0.sortOrder == $1.sortOrder ? $0.name < $1.name : $0.sortOrder < $1.sortOrder
        }
    }

    private var parsedAmount: Decimal {
        Decimal(string: amountText.replacingOccurrences(of: ",", with: "")) ?? .zero
    }

    private var trimmedMerchant: String {
        merchant.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isValid: Bool {
        parsedAmount > .zero && !trimmedMerchant.isEmpty
    }

    private var amountField: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            Text(appStore.preferences?.currencyCode ?? "INR")
                .font(.headline)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
            TextField("0", text: $amountText)
                .platformDecimalKeyboard()
                .multilineTextAlignment(.trailing)
                .font(.system(.title2, design: .rounded).monospacedDigit().weight(.semibold))
                .platformAmountFieldWidth()
                .accessibilityLabel("Amount")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $kind) {
                        ForEach(TransactionKind.allCases, id: \.self) { value in
                            Text(value.displayName).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)

                    LabeledContent("Amount") {
                        amountField
                    }

                    TextField("Merchant or title", text: $merchant)
                        .platformWordsAutocapitalization()
                } header: {
                    Text("What happened?")
                } footer: {
                    if let validationMessage {
                        Text(validationMessage)
                            .foregroundStyle(DesignSystem.Colors.danger)
                    } else {
                        Text("Use a positive amount. The transaction type determines how it affects your totals.")
                    }
                }

                if kind == .expense || kind == .refund {
                    Section("Category") {
                        Picker("Category", selection: $categoryID) {
                            Text("Uncategorized").tag(Optional<UUID>.none)
                            ForEach(visibleCategories, id: \.id) { category in
                                Label(category.name, systemImage: category.iconName)
                                    .tag(Optional(category.id))
                            }
                        }
                        if visibleCategories.isEmpty {
                            Text("No active categories yet. You can add one from Settings.")
                                .font(.footnote)
                                .foregroundStyle(DesignSystem.Colors.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                Section("When") {
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }

                Section("Details") {
                    TextField("Notes (optional)", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                        .platformMultilineField(minHeight: 80)
                    TextField("Payment method (optional)", text: $paymentMethod)
                        .platformWordsAutocapitalization()
                }

                if transaction != nil {
                    Section {
                        Button("Delete transaction", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(DesignSystem.Colors.background)
            .platformFormLayout()
            .navigationTitle(transaction == nil ? (subscriptionToRecord == nil ? "Add transaction" : "Record charge") : "Edit transaction")
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
            .onChange(of: kind) { _, newValue in
                if newValue == .income || newValue == .transfer {
                    categoryID = nil
                }
            }
            .confirmationDialog("Delete this transaction?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let transaction {
                        appStore.deleteTransaction(transaction)
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
        }
        .platformSheetFrame(minWidth: 680, idealWidth: 760, minHeight: 620, idealHeight: 760)
#if os(iOS)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
#endif
    }

    private func save() {
        guard isValid else {
            validationMessage = "Enter a title and an amount greater than zero."
            return
        }

        if let transaction {
            transaction.kind = kind
            transaction.amount = parsedAmount
            transaction.merchant = trimmedMerchant
            transaction.categoryID = kind == .expense || kind == .refund ? categoryID : nil
            transaction.linkedSubscriptionID = linkedSubscriptionID
            transaction.date = date
            transaction.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
            transaction.paymentMethod = paymentMethod.trimmingCharacters(in: .whitespacesAndNewlines)
            transaction.updatedAt = Date()
        } else {
            if appStore.recordTransaction(
                date: date,
                amount: parsedAmount,
                merchant: trimmedMerchant,
                note: note,
                paymentMethod: paymentMethod,
                categoryID: categoryID,
                linkedSubscriptionID: linkedSubscriptionID,
                kind: kind
            ) != nil {
                dismiss()
            }
            return
        }

        if appStore.save() {
            dismiss()
        }
    }
}
