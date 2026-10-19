import SwiftUI
import SwiftData

struct BudgetsView: View {
    @EnvironmentObject private var appStore: AppStore
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \BudgetCategory.sortOrder) private var categories: [BudgetCategory]
    @Query(sort: \BudgetPlan.monthStart) private var plans: [BudgetPlan]

    @State private var showPlanEditor = false
    @State private var selectedCategory: BudgetCategory?
    @State private var showCategoryPicker = false

    private var selectedMonth: Date { appStore.selectedMonth }
    private var currencyCode: String { appStore.preferences?.currencyCode ?? "INR" }
    private var preferences: AppPreferences? { appStore.preferences }

    private var visibleCategories: [BudgetCategory] {
        categories.filter { !$0.isArchived }.sorted {
            $0.sortOrder == $1.sortOrder ? $0.name < $1.name : $0.sortOrder < $1.sortOrder
        }
    }

    private var monthPlans: [BudgetPlan] {
        plans.filter { appStore.calendar.isDate($0.monthStart, equalTo: selectedMonth, toGranularity: .month) }
    }

    private var summary: MonthSummary {
        FinancialCalculator.monthSummary(for: selectedMonth, transactions: transactions, calendar: appStore.calendar)
    }

    private var allowance: Decimal { preferences?.monthlySpendingAllowance ?? .zero }
    private var remaining: Decimal { allowance - summary.spending }
    private var overallProgress: Double {
        guard allowance > .zero else { return 0 }
        return max(0, NSDecimalNumber(decimal: summary.spending / allowance).doubleValue)
    }

    var body: some View {
        PageScaffold {
            pageHeader
            overviewSurface
            categorySection
            planningNote
        }
        .navigationTitle("Budgets")
        .platformLargeNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .platformTrailing) {
                Menu {
                    Button {
                        showPlanEditor = true
                    } label: {
                        Label("Edit monthly plan", systemImage: "slider.horizontal.3")
                    }
                    Button {
                        showCategoryPicker = true
                    } label: {
                        Label("Add category limit", systemImage: "plus")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Budget actions")
            }
        }
        .sheet(isPresented: $showPlanEditor) {
            MonthlyPlanEditorView(month: selectedMonth)
        }
        .sheet(isPresented: $showCategoryPicker) {
            CategoryBudgetPickerView(
                categoriesWithPlans: Set(monthPlans.map(\.categoryID))
            ) { category in
                selectedCategory = category
                showCategoryPicker = false
            }
        }
        .sheet(item: $selectedCategory) { category in
            CategoryBudgetEditorView(category: category, month: selectedMonth, existingPlan: plan(for: category))
        }
    }

    private var pageHeader: some View {
        PageHeader("Give every rupee a role", title: "Your monthly plan") {
            MonthSelector(month: $appStore.selectedMonth, calendar: appStore.calendar)
        }
    }

    private var overviewSurface: some View {
        FinancialSurface(style: .emphasized, cornerRadius: DesignSystem.Radius.large) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxxSmall) {
                        Text("Remaining")
                            .font(.subheadline)
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                        MoneyText(
                            remaining,
                            currencyCode: currencyCode,
                            font: .system(size: 32, design: .rounded).monospacedDigit().weight(.semibold),
                            color: remaining >= .zero ? DesignSystem.Colors.success : DesignSystem.Colors.danger
                        )
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xxxSmall) {
                        Text("Spent")
                            .font(.caption)
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                        MoneyText(summary.spending, currencyCode: currencyCode, font: .subheadline.monospacedDigit().weight(.semibold))
                        if allowance > .zero {
                            Text("of \(MoneyTextValue.string(allowance, currencyCode: currencyCode))")
                                .font(.caption)
                                .foregroundStyle(DesignSystem.Colors.secondaryText)
                        } else {
                            Text("No allowance set")
                                .font(.caption)
                                .foregroundStyle(DesignSystem.Colors.secondaryText)
                        }
                    }
                }

                BudgetProgressBar(
                    progress: overallProgress,
                    tint: remaining >= .zero ? DesignSystem.Colors.success : DesignSystem.Colors.danger,
                    accessibilityLabel: "Overall monthly budget"
                )

                HStack {
                    Label(
                        allowance > .zero ? "\(Int((overallProgress * 100).rounded()))% used" : "Add an allowance to see progress",
                        systemImage: allowance > .zero ? "chart.bar.fill" : "plus.circle"
                    )
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)

                    Spacer()

                    Button("Edit") {
                        showPlanEditor = true
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.success)
                }
            }
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            SectionHeader(
                "Category limits",
                subtitle: "Keep limits explicit. Nothing rolls over unless you change it."
            )

            if visibleCategories.isEmpty {
                EmptyStateView(
                    systemImage: "square.grid.2x2",
                    title: "No categories yet",
                    message: "Add a category in Settings before setting a limit."
                )
            } else {
                FinancialSurface(padding: EdgeInsets(top: 8, leading: DesignSystem.Spacing.medium, bottom: 8, trailing: DesignSystem.Spacing.medium)) {
                    ForEach(visibleCategories, id: \.id) { category in
                        let status = status(for: category)
                        CategoryBudgetRow(
                            category: category,
                            spent: status.spent,
                            limit: status.limit,
                            currencyCode: currencyCode
                        ) {
                            selectedCategory = category
                        }
                        if category.id != visibleCategories.last?.id {
                            Divider().overlay(DesignSystem.Colors.divider)
                        }
                    }
                }
            }
        }
    }

    private var planningNote: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.small) {
            Image(systemName: "info.circle")
                .foregroundStyle(DesignSystem.Colors.accent)
            Text("Income and savings goals are tracked separately from your spending allowance. Transfers do not count as spending, and refunds offset the category where they were recorded.")
                .font(.footnote)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
        }
        .padding(.horizontal, DesignSystem.Spacing.small)
    }

    private func plan(for category: BudgetCategory) -> BudgetPlan? {
        monthPlans.first { $0.categoryID == category.id }
    }

    private func status(for category: BudgetCategory) -> BudgetStatus {
        if let plan = plan(for: category) {
            return FinancialCalculator.budgetStatus(for: plan, transactions: transactions, calendar: appStore.calendar)
        }
        return BudgetStatus(
            planID: UUID(),
            categoryID: category.id,
            monthStart: selectedMonth,
            limit: .zero,
            spent: summary.categoryTotals[category.id] ?? .zero,
            remaining: -(summary.categoryTotals[category.id] ?? .zero),
            percentage: nil
        )
    }
}

private struct MonthlyPlanEditorView: View {
    @EnvironmentObject private var appStore: AppStore
    @Environment(\.dismiss) private var dismiss
    let month: Date

    @State private var allowanceText = ""
    @State private var incomeText = ""
    @State private var savingsText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    AmountInputRow(title: "Spending allowance", text: $allowanceText, currencyCode: currencyCode)
                    AmountInputRow(title: "Income target", text: $incomeText, currencyCode: currencyCode, optional: true)
                    AmountInputRow(title: "Savings goal", text: $savingsText, currencyCode: currencyCode, optional: true)
                } header: {
                    Text(month, format: .dateTime.month(.wide).year())
                } footer: {
                    Text("The allowance is the amount you plan to spend. Income and savings are reference goals and are never mixed into spending totals.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(DesignSystem.Colors.canvas)
            .platformFormLayout()
            .navigationTitle("Monthly plan")
            .platformInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.glass)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .buttonStyle(.glassProminent)
                    .fontWeight(.semibold)
                }
            }
        }
        .platformSheetFrame(minWidth: 620, idealWidth: 720, minHeight: 420, idealHeight: 520)
#if os(iOS)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
#endif
        .onAppear {
            allowanceText = stringValue(appStore.preferences?.monthlySpendingAllowance ?? .zero)
            incomeText = stringValue(appStore.preferences?.monthlyIncomeTarget ?? .zero)
            savingsText = stringValue(appStore.preferences?.monthlySavingsGoal ?? .zero)
        }
    }

    private var currencyCode: String { appStore.preferences?.currencyCode ?? "INR" }

    private func save() {
        let preferences = appStore.preferences ?? appStore.makePreferences()
        preferences.monthlySpendingAllowance = decimalValue(allowanceText)
        preferences.monthlyIncomeTarget = decimalValue(incomeText)
        preferences.monthlySavingsGoal = decimalValue(savingsText)
        if appStore.save() { dismiss() }
    }

    private func decimalValue(_ text: String) -> Decimal {
        Decimal(string: text.replacingOccurrences(of: ",", with: "")) ?? .zero
    }

    private func stringValue(_ value: Decimal) -> String {
        let number = NSDecimalNumber(decimal: value)
        return number == .zero ? "" : number.stringValue
    }
}

private struct CategoryBudgetEditorView: View {
    @EnvironmentObject private var appStore: AppStore
    @Environment(\.dismiss) private var dismiss
    let category: BudgetCategory
    let month: Date
    let existingPlan: BudgetPlan?

    @State private var limitText = ""
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: DesignSystem.Spacing.medium) {
                        CategoryIconView(systemName: category.iconName, color: Color(hex: category.colorHex), size: DesignSystem.Size.iconLarge, accessibilityLabel: category.name)
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxxSmall) {
                            Text(category.name)
                                .font(.headline)
                            Text(month, format: .dateTime.month(.wide).year())
                                .font(.subheadline)
                                .foregroundStyle(DesignSystem.Colors.secondaryText)
                        }
                    }
                    AmountInputRow(title: "Monthly limit", text: $limitText, currencyCode: currencyCode)
                } footer: {
                    Text("A zero limit is treated as no limit. Spending still appears in the category overview.")
                }

                if existingPlan != nil {
                    Section {
                        Button("Remove limit", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(DesignSystem.Colors.canvas)
            .platformFormLayout()
            .navigationTitle("Category limit")
            .platformInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.glass)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .buttonStyle(.glassProminent)
                        .fontWeight(.semibold)
                }
            }
            .confirmationDialog("Remove this limit?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Remove", role: .destructive) {
                    if let existingPlan {
                        appStore.deleteBudgetPlan(existingPlan)
                    }
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            }
        }
        .platformSheetFrame(minWidth: 560, idealWidth: 640, minHeight: 360, idealHeight: 460)
#if os(iOS)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
#endif
        .onAppear {
            if let existingPlan {
                limitText = NSDecimalNumber(decimal: existingPlan.limit).stringValue
            }
        }
    }

    private var currencyCode: String { appStore.preferences?.currencyCode ?? "INR" }

    private func save() {
        _ = appStore.upsertBudgetPlan(
            for: month,
            categoryID: category.id,
            limit: Decimal(string: limitText.replacingOccurrences(of: ",", with: "")) ?? .zero
        )
        dismiss()
    }
}

private struct CategoryBudgetPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \BudgetCategory.sortOrder) private var allCategories: [BudgetCategory]
    let categoriesWithPlans: Set<UUID>
    let onSelect: (BudgetCategory) -> Void

    private var categories: [BudgetCategory] {
        allCategories.filter { !$0.isArchived }.sorted {
            $0.sortOrder == $1.sortOrder ? $0.name < $1.name : $0.sortOrder < $1.sortOrder
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if categories.isEmpty {
                    EmptyStateView(
                        systemImage: "square.grid.2x2",
                        title: "No active categories",
                        message: "Create or restore a category in Settings before adding a budget limit.",
                        actionTitle: "Close"
                    ) {
                        dismiss()
                    }
                    .frame(minHeight: 240)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(categories, id: \.id) { category in
                        Button {
                            onSelect(category)
                        } label: {
                            HStack {
                                Label(category.name, systemImage: category.iconName)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                                if categoriesWithPlans.contains(category.id) {
                                    Text("Edit")
                                        .font(.caption)
                                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Choose category")
            .platformInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .platformSheetFrame(minWidth: 480, idealWidth: 560, minHeight: 360, idealHeight: 440)
#if os(iOS)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
#endif
    }
}

private struct AmountInputRow: View {
    let title: String
    @Binding var text: String
    let currencyCode: String
    var optional = false

    private var amountField: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            Text(currencyCode)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.secondaryText)
            TextField(optional ? "Optional" : "0", text: $text)
                .platformDecimalKeyboard()
                .multilineTextAlignment(.trailing)
                .platformAmountFieldWidth()
                .font(.body.monospacedDigit())
        }
    }

    var body: some View {
        LabeledContent(title) {
            amountField
        }
    }
}
