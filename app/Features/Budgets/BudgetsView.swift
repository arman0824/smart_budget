import SwiftUI
import SwiftData

struct BudgetsView: View {
    @EnvironmentObject private var appStore: AppStore
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \BudgetCategory.sortOrder) private var categories: [BudgetCategory]
    @Query(sort: \BudgetPlan.monthStart) private var plans: [BudgetPlan]

    @State private var selectedMonth = Date()
    @State private var showPlanEditor = false
    @State private var selectedCategory: BudgetCategory?
    @State private var showCategoryPicker = false

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
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
                monthHeader
                overviewSurface
                categorySection
                planningNote
            }
            .padding(.horizontal, DesignSystem.Spacing.large)
            .padding(.top, DesignSystem.Spacing.small)
            .padding(.bottom, DesignSystem.Spacing.xxLarge)
        }
        .background(DesignSystem.Colors.background.ignoresSafeArea())
        .navigationTitle("Budgets")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
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
                .accessibilityLabel("Budget actions")
            }
        }
        .sheet(isPresented: $showPlanEditor) {
            MonthlyPlanEditorView(month: selectedMonth)
        }
        .sheet(isPresented: $showCategoryPicker) {
            CategoryBudgetPickerView(
                categories: visibleCategories,
                categoriesWithPlans: Set(monthPlans.map(\.categoryID))
            ) { category in
                selectedCategory = category
                showCategoryPicker = false
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $selectedCategory) { category in
            CategoryBudgetEditorView(category: category, month: selectedMonth, existingPlan: plan(for: category))
        }
        .onAppear {
            selectedMonth = appStore.selectedMonth
        }
    }

    private var monthHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxxSmall) {
                Text("Give every rupee a role")
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                Text("Your monthly plan")
                    .font(.title3.weight(.semibold))
            }
            Spacer()
            MonthSelector(month: $selectedMonth, calendar: appStore.calendar)
        }
    }

    private var overviewSurface: some View {
        FinancialSurface(cornerRadius: DesignSystem.Radius.large) {
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
            .background(DesignSystem.Colors.background)
            .navigationTitle("Monthly plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
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
            .background(DesignSystem.Colors.background)
            .navigationTitle("Category limit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
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
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
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
    let categories: [BudgetCategory]
    let categoriesWithPlans: Set<UUID>
    let onSelect: (BudgetCategory) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(categories, id: \.id) { category in
                    Button {
                        onSelect(category)
                    } label: {
                        HStack {
                            Label(category.name, systemImage: category.iconName)
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
            .navigationTitle("Choose category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct AmountInputRow: View {
    let title: String
    @Binding var text: String
    let currencyCode: String
    var optional = false

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(currencyCode)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.secondaryText)
            TextField(optional ? "Optional" : "0", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(minWidth: 110)
                .font(.body.monospacedDigit())
        }
    }
}
