#if os(macOS)
import AppKit
import SwiftData
import SwiftUI

struct QuickLogView: View {
    @EnvironmentObject private var appStore: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \BudgetCategory.sortOrder) private var categories: [BudgetCategory]

    @State private var kind: TransactionKind = .expense
    @State private var amountText = ""
    @State private var merchant = ""
    @State private var categoryID: UUID?
    @State private var date = Date()
    @State private var note = ""
    @State private var validationMessage: String?
    @FocusState private var focusedField: FocusedField?

    private enum FocusedField: Hashable {
        case amount
        case merchant
        case note
    }

    private var visibleCategories: [BudgetCategory] {
        categories
            .filter { !$0.isArchived }
            .sorted {
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

    private var categoryIsApplicable: Bool {
        kind == .expense || kind == .refund
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            Form {
                Section {
                    Picker("Type", selection: $kind) {
                        ForEach(TransactionKind.allCases, id: \.self) { value in
                            Text(value.displayName).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)

                    LabeledContent("Amount") {
                        HStack(spacing: DesignSystem.Spacing.xSmall) {
                            Text(appStore.preferences?.currencyCode ?? "INR")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(DesignSystem.Colors.secondaryText)

                            TextField("0", text: $amountText)
                                .platformDecimalKeyboard()
                                .multilineTextAlignment(.trailing)
                                .font(.system(.title3, design: .rounded).monospacedDigit().weight(.semibold))
                                .frame(minWidth: 120)
                                .focused($focusedField, equals: .amount)
                                .accessibilityLabel("Amount")
                        }
                    }

                    TextField("Merchant or title", text: $merchant)
                        .platformWordsAutocapitalization()
                        .focused($focusedField, equals: .merchant)
                } header: {
                    Text("What happened?")
                } footer: {
                    if let validationMessage {
                        Text(validationMessage)
                            .foregroundStyle(DesignSystem.Colors.danger)
                    } else {
                        Text("Use a positive amount. The type determines how it affects your totals.")
                    }
                }

                if categoryIsApplicable {
                    Section("Category") {
                        Picker("Category", selection: $categoryID) {
                            Text("Uncategorized").tag(Optional<UUID>.none)
                            ForEach(visibleCategories, id: \.id) { category in
                                Label(category.name, systemImage: category.iconName)
                                    .tag(Optional(category.id))
                            }
                        }

                        if visibleCategories.isEmpty {
                            Text("No active categories yet. Add one from Settings.")
                                .font(.footnote)
                                .foregroundStyle(DesignSystem.Colors.secondaryText)
                        }
                    }
                }

                Section("When") {
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }

                Section("Details") {
                    TextField("Note (optional)", text: $note, axis: .vertical)
                        .lineLimit(1...3)
                        .focused($focusedField, equals: .note)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .frame(height: 430)

            Divider()

            footerActions
        }
        .frame(width: 380)
        .background(DesignSystem.Colors.background)
        .onAppear {
            Task { @MainActor in
                await Task.yield()
                focusedField = .amount
            }
        }
        .onChange(of: kind) { _, newValue in
            if newValue == .income || newValue == .transfer {
                categoryID = nil
            }
            validationMessage = nil
        }
        .onChange(of: amountText) { _, _ in
            validationMessage = nil
        }
        .onChange(of: merchant) { _, _ in
            validationMessage = nil
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxxSmall) {
            HStack(spacing: DesignSystem.Spacing.small) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(DesignSystem.Colors.success)
                    .accessibilityHidden(true)

                Text("Quick Log")
                    .font(.headline)
                    .foregroundStyle(DesignSystem.Colors.primaryText)
            }

            Text("Capture a transaction without opening Smart Budget.")
                .font(.subheadline)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.vertical, DesignSystem.Spacing.small)
    }

    private var footerActions: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            Button("Open Smart Budget") {
                Task { @MainActor in
                    openWindow(id: "main")
                    await Task.yield()
                    dismiss()
                }
            }
            .buttonStyle(.link)

            Spacer(minLength: DesignSystem.Spacing.small)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .foregroundStyle(DesignSystem.Colors.secondaryText)

            Button("Save") {
                save()
            }
            .buttonStyle(.glassProminent)
            .tint(DesignSystem.Colors.success)
            .disabled(!isValid)
            .keyboardShortcut(.defaultAction)
        }
        .padding(DesignSystem.Spacing.medium)
    }

    private func save() {
        guard isValid else {
            validationMessage = trimmedMerchant.isEmpty
                ? "Enter a merchant or title."
                : "Enter an amount greater than zero."
            focusedField = trimmedMerchant.isEmpty ? .merchant : .amount
            return
        }

        if appStore.recordTransaction(
            date: date,
            amount: parsedAmount,
            merchant: trimmedMerchant,
            note: note,
            categoryID: categoryID,
            kind: kind
        ) != nil {
            dismiss()
        }
    }
}
#endif
