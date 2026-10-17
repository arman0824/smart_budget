import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var appStore: AppStore
    @Environment(\.dismiss) private var dismiss
    @Query private var preferences: [AppPreferences]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \BudgetCategory.sortOrder) private var categories: [BudgetCategory]

    @State private var selectedCurrency = "INR"
    @State private var notificationsEnabled = false
    @State private var showExporter = false
    @State private var exportDocument = TransactionCSVDocument()
    @State private var showResetConfirmation = false
    @State private var message: String?

    private let currencies = [
        ("INR", "Indian rupee"),
        ("USD", "US dollar"),
        ("EUR", "Euro"),
        ("GBP", "British pound"),
        ("AUD", "Australian dollar"),
        ("CAD", "Canadian dollar"),
        ("SGD", "Singapore dollar"),
        ("JPY", "Japanese yen")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Preferences") {
                    Picker("Currency", selection: $selectedCurrency) {
                        ForEach(currencies, id: \.0) { currency in
                            Text("\(currency.0) · \(currency.1)").tag(currency.0)
                        }
                    }
                    .onChange(of: selectedCurrency) { _, newValue in
                        appStore.updateCurrency(newValue)
                    }

                    NavigationLink {
                        MonthlyPlanSettingsView()
                    } label: {
                        Label("Monthly plan", systemImage: "target")
                    }

                    NavigationLink {
                        CategoryManagementView()
                    } label: {
                        Label("Categories", systemImage: "square.grid.2x2")
                    }
                }

                Section {
                    Toggle("Renewal reminders", isOn: $notificationsEnabled)
                        .tint(DesignSystem.Colors.success)
                        .onChange(of: notificationsEnabled) { _, isEnabled in
                            updateNotifications(isEnabled)
                        }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Reminders are local to this device. iOS may still delay notifications because of Focus, power, or system settings.")
                }

                Section("Data") {
                    Button {
                        exportDocument = CSVExportService.document(
                            for: transactions,
                            categoryNames: Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
                        )
                        showExporter = true
                    } label: {
                        Label("Export transactions as CSV", systemImage: "square.and.arrow.up")
                    }

                    if appStore.preferences?.hasSampleData == true {
                        Button("Remove sample data", role: .destructive) {
                            showResetConfirmation = true
                        }
                    }

                    Text("Export includes transaction date, merchant, category, type, amount, and notes. It does not upload anything.")
                        .font(.footnote)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                }

                Section("Privacy") {
                    Label("Local-first storage", systemImage: "lock.shield")
                    Text("Your financial records stay in the app's SwiftData store. This version has no account, bank connection, cloud sync, analytics SDK, or server backup.")
                        .font(.footnote)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("Storage", value: "On-device SwiftData")
                    LabeledContent("Supported", value: "iOS 27 and later")
                }
            }
            .scrollContentBackground(.hidden)
            .background(DesignSystem.Colors.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .fileExporter(
                isPresented: $showExporter,
                document: exportDocument,
                contentType: .commaSeparatedText,
                defaultFilename: "smart-budget-transactions"
            ) { result in
                if case .failure = result {
                    message = "The CSV export could not be completed."
                }
            }
            .confirmationDialog("Remove sample data?", isPresented: $showResetConfirmation, titleVisibility: .visible) {
                Button("Remove sample data", role: .destructive) {
                    appStore.clearSampleData()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Only entries created by Explore with sample data will be removed. Your own records remain.")
            }
            .alert("Settings", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK", role: .cancel) { message = nil }
            } message: {
                Text(message ?? "")
            }
        }
        .onAppear {
            selectedCurrency = appStore.preferences?.currencyCode ?? "INR"
            notificationsEnabled = appStore.preferences?.notificationsEnabled ?? false
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private func updateNotifications(_ isEnabled: Bool) {
        let preferences = appStore.preferences ?? appStore.makePreferences()
        preferences.notificationsEnabled = isEnabled
        _ = appStore.save()

        if isEnabled {
            Task {
                let granted = await appStore.requestNotificationPermission()
                if !granted {
                    notificationsEnabled = false
                    preferences.notificationsEnabled = false
                    _ = appStore.save()
                } else {
                    appStore.scheduleAllReminders()
                }
            }
        } else {
            appStore.notificationService.cancelReminders(for: appStore.fetchSubscriptions())
        }
    }
}

private struct MonthlyPlanSettingsView: View {
    @EnvironmentObject private var appStore: AppStore
    @State private var allowance = ""
    @State private var incomeTarget = ""
    @State private var savingsGoal = ""

    var body: some View {
        Form {
            Section {
                AmountSettingRow(title: "Spending allowance", value: $allowance, currencyCode: currencyCode)
                AmountSettingRow(title: "Income target", value: $incomeTarget, currencyCode: currencyCode)
                AmountSettingRow(title: "Savings goal", value: $savingsGoal, currencyCode: currencyCode)
            } header: {
                Text("Monthly targets")
            } footer: {
                Text("These values are stored locally and used by the Overview and Budgets screens. Income does not increase your spending allowance automatically.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(DesignSystem.Colors.background)
        .navigationTitle("Monthly plan")
        .onAppear {
            allowance = stringValue(appStore.preferences?.monthlySpendingAllowance ?? .zero)
            incomeTarget = stringValue(appStore.preferences?.monthlyIncomeTarget ?? .zero)
            savingsGoal = stringValue(appStore.preferences?.monthlySavingsGoal ?? .zero)
        }
        .onDisappear {
            let preferences = appStore.preferences ?? appStore.makePreferences()
            preferences.monthlySpendingAllowance = decimalValue(allowance)
            preferences.monthlyIncomeTarget = decimalValue(incomeTarget)
            preferences.monthlySavingsGoal = decimalValue(savingsGoal)
            _ = appStore.save()
        }
    }

    private var currencyCode: String { appStore.preferences?.currencyCode ?? "INR" }

    private func decimalValue(_ value: String) -> Decimal {
        Decimal(string: value.replacingOccurrences(of: ",", with: "")) ?? .zero
    }

    private func stringValue(_ value: Decimal) -> String {
        value == .zero ? "" : NSDecimalNumber(decimal: value).stringValue
    }
}

private struct AmountSettingRow: View {
    let title: String
    @Binding var value: String
    let currencyCode: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(currencyCode)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.secondaryText)
            TextField("0", text: $value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(minWidth: 100)
                .font(.body.monospacedDigit())
        }
    }
}

private struct CategoryManagementView: View {
    @EnvironmentObject private var appStore: AppStore
    @Query(sort: \BudgetCategory.sortOrder) private var categories: [BudgetCategory]
    @Query private var transactions: [Transaction]

    @State private var categoryToEdit: BudgetCategory?
    @State private var showNewCategory = false
    @State private var message: String?

    private var visibleCategories: [BudgetCategory] {
        categories.filter { !$0.isArchived }.sorted {
            $0.sortOrder == $1.sortOrder ? $0.name < $1.name : $0.sortOrder < $1.sortOrder
        }
    }

    var body: some View {
        List {
            Section {
                ForEach(visibleCategories, id: \.id) { category in
                    Button {
                        categoryToEdit = category
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.medium) {
                            CategoryIconView(systemName: category.iconName, color: Color(hex: category.colorHex), size: DesignSystem.Size.iconSmall, accessibilityLabel: category.name)
                            Text(category.name)
                                .foregroundStyle(DesignSystem.Colors.primaryText)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(DesignSystem.Colors.secondaryText)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onMove(perform: move)
                .onDelete(perform: delete)
            } header: {
                Text("Expense categories")
            } footer: {
                Text("Categories with transactions are archived instead of deleted so your history remains understandable.")
            }
        }
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNewCategory = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add category")
            }
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
        }
        .sheet(isPresented: $showNewCategory) {
            CategoryEditorView(category: nil)
        }
        .sheet(item: $categoryToEdit) { category in
            CategoryEditorView(category: category)
        }
        .alert("Category", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    private func move(from offsets: IndexSet, to destination: Int) {
        var reordered = visibleCategories
        reordered.move(fromOffsets: offsets, toOffset: destination)
        for (index, category) in reordered.enumerated() {
            category.sortOrder = index
        }
        _ = appStore.save()
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let category = visibleCategories[index]
            if !appStore.deleteCategory(category) {
                message = "\(category.name) still has transactions, so it was archived instead of deleted."
            }
        }
    }
}

private struct CategoryEditorView: View {
    @EnvironmentObject private var appStore: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let category: BudgetCategory?
    @State private var name: String
    @State private var iconName: String
    @State private var colorHex: String

    private let iconChoices = ["tag.fill", "house.fill", "fork.knife", "cart.fill", "car.fill", "bolt.fill", "bag.fill", "play.rectangle.fill", "heart.fill", "book.fill", "airplane", "sparkles", "ellipsis.circle.fill"]
    private let colorChoices = ["#258563", "#6487CE", "#D5A04A", "#D96A6A", "#7C3AED", "#0891B2", "#DB2777", "#64748B"]

    init(category: BudgetCategory?) {
        self.category = category
        _name = State(initialValue: category?.name ?? "")
        _iconName = State(initialValue: category?.iconName ?? "tag.fill")
        _colorHex = State(initialValue: category?.colorHex ?? "#258563")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                    Picker("Icon", selection: $iconName) {
                        ForEach(iconChoices, id: \.self) { icon in
                            Label(icon.replacingOccurrences(of: ".fill", with: ""), systemImage: icon).tag(icon)
                        }
                    }
                    Picker("Color", selection: $colorHex) {
                        ForEach(colorChoices, id: \.self) { color in
                            HStack {
                                Circle().fill(Color(hex: color)).frame(width: 18, height: 18)
                                Text(color)
                            }
                            .tag(color)
                        }
                    }
                }
                Section {
                    HStack {
                        CategoryIconView(systemName: iconName, color: Color(hex: colorHex), size: DesignSystem.Size.iconLarge, accessibilityLabel: name.isEmpty ? "Category preview" : name)
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxxSmall) {
                            Text(name.isEmpty ? "Category preview" : name)
                                .font(.headline)
                            Text("Used for expenses, budgets, and insights")
                                .font(.caption)
                                .foregroundStyle(DesignSystem.Colors.secondaryText)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(DesignSystem.Colors.background)
            .navigationTitle(category == nil ? "New category" : "Edit category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        if let category {
            category.name = trimmedName
            category.iconName = iconName
            category.colorHex = colorHex
        } else {
            let highestSortOrder = (appStore.categories.map(\.sortOrder).max() ?? -1) + 1
            modelContext.insert(BudgetCategory(name: trimmedName, iconName: iconName, colorHex: colorHex, sortOrder: highestSortOrder))
        }

        if appStore.save() { dismiss() }
    }
}
