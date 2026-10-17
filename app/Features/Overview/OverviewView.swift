import Charts
import SwiftUI
import SwiftData

struct OverviewView: View {
    @EnvironmentObject private var appStore: AppStore
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \BudgetCategory.sortOrder) private var categories: [BudgetCategory]
    @Query(sort: \Subscription.nextBillingDate) private var subscriptions: [Subscription]
    @Query private var budgets: [BudgetPlan]

    @State private var selectedMonth = Date()
    @State private var snapshotRange: SnapshotRange = .month
    @State private var showSettings = false
    @State private var showTransactionForm = false
    @State private var selectedTransaction: Transaction?

    private var preferences: AppPreferences? { appStore.preferences }
    private var currencyCode: String { preferences?.currencyCode ?? "INR" }
    private var visibleCategories: [BudgetCategory] { categories.filter { !$0.isArchived } }
    private var summary: MonthSummary {
        FinancialCalculator.monthSummary(for: selectedMonth, transactions: transactions, calendar: appStore.calendar)
    }
    private var allowance: Decimal { preferences?.monthlySpendingAllowance ?? .zero }
    private var remaining: Decimal { allowance - summary.spending }
    private var progress: Double {
        guard allowance > .zero else { return 0 }
        return max(0, NSDecimalNumber(decimal: summary.spending / allowance).doubleValue)
    }
    private var categoryNames: [UUID: String] { Dictionary(uniqueKeysWithValues: visibleCategories.map { ($0.id, $0.name) }) }
    private var insights: [FinancialInsight] {
        FinancialCalculator.deterministicInsights(
            for: selectedMonth,
            transactions: transactions,
            budgets: budgets,
            subscriptions: subscriptions,
            categoryNames: categoryNames,
            calendar: appStore.calendar
        )
    }
    private var topCategories: [OverviewCategory] {
        visibleCategories
            .compactMap { category in
                let spent = summary.categoryTotals[category.id] ?? .zero
                guard spent > .zero else { return nil }
                let limit = budgets.first {
                    $0.categoryID == category.id && appStore.calendar.isDate($0.monthStart, equalTo: selectedMonth, toGranularity: .month)
                }?.limit ?? .zero
                return OverviewCategory(category: category, spent: spent, limit: limit)
            }
            .sorted { $0.spent > $1.spent }
            .prefix(3)
            .map { $0 }
    }
    private var upcomingPayments: [Subscription] {
        let now = Date()
        let thirtyDaysFromNow = appStore.calendar.date(byAdding: .day, value: 30, to: now) ?? now
        return subscriptions.filter {
            $0.status.canHaveUpcomingPayment && $0.nextBillingDate.map { $0 >= now && $0 <= thirtyDaysFromNow } == true
        }
        .sorted { ($0.nextBillingDate ?? .distantFuture) < ($1.nextBillingDate ?? .distantFuture) }
        .prefix(3)
        .map { $0 }
    }
    private var recentTransactions: [Transaction] {
        transactions
            .filter { appStore.calendar.isDate($0.date, equalTo: selectedMonth, toGranularity: .month) }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
                header
                if preferences?.hasSampleData == true {
                    sampleDataBanner
                }
                summarySurface
                budgetHealth
                spendingSnapshot
                upcomingSection
                recentSection
                insightsSection
            }
            .padding(.horizontal, DesignSystem.Spacing.large)
            .padding(.top, DesignSystem.Spacing.small)
            .padding(.bottom, DesignSystem.Spacing.xxLarge)
        }
        .background(DesignSystem.Colors.background.ignoresSafeArea())
        .navigationTitle("Your finances")
        .platformLargeNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .platformLeading) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(greeting)
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                    Text("A calm view of today")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                }
                .accessibilityElement(children: .combine)
            }
            ToolbarItemGroup(placement: .platformTrailing) {
                Button {
                    selectedTransaction = nil
                    showTransactionForm = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add transaction")
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showTransactionForm) {
            TransactionFormView(transaction: selectedTransaction)
        }
        .onAppear {
            selectedMonth = appStore.selectedMonth
        }
        .onChange(of: selectedMonth) { _, newMonth in
            appStore.selectedMonth = newMonth
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxxSmall) {
                Text("Good \(greeting.lowercased())")
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                Text("Your finances")
                    .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.primaryText)
            }
            Spacer(minLength: DesignSystem.Spacing.small)
            MonthSelector(month: $selectedMonth, calendar: appStore.calendar)
        }
    }

    private var summarySurface: some View {
        FinancialSurface(cornerRadius: 24) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxxSmall) {
                        Text("Remaining this month")
                            .font(.subheadline)
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                        MoneyText(
                            remaining,
                            currencyCode: currencyCode,
                            font: .system(size: 36, design: .rounded).monospacedDigit().weight(.semibold),
                            color: remaining >= .zero ? DesignSystem.Colors.success : DesignSystem.Colors.danger
                        )
                        .contentTransition(.numericText())
                    }
                    Spacer(minLength: DesignSystem.Spacing.medium)
                    Image(systemName: remaining >= .zero ? "checkmark.seal" : "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundStyle(remaining >= .zero ? DesignSystem.Colors.success : DesignSystem.Colors.danger)
                        .accessibilityHidden(true)
                }

                BudgetProgressBar(
                    progress: progress,
                    tint: remaining >= .zero ? DesignSystem.Colors.success : DesignSystem.Colors.danger,
                    accessibilityLabel: "Monthly spending budget"
                )

                HStack {
                    Text(allowance > .zero ? "\(Int((progress * 100).rounded()))% of allowance used" : "Set an allowance to track progress")
                        .font(.subheadline)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                    Spacer()
                    Text(selectedMonth, format: .dateTime.month(.wide).year())
                        .font(.caption.weight(.medium))
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                }

                Divider().overlay(DesignSystem.Colors.divider)

                HStack(spacing: DesignSystem.Spacing.large) {
                    SummaryValue(title: "Spent", amount: summary.spending, currencyCode: currencyCode, color: DesignSystem.Colors.primaryText)
                    SummaryValue(title: "Income", amount: summary.income, currencyCode: currencyCode, color: DesignSystem.Colors.success)
                    Spacer()
                }
            }
        }
    }

    private var sampleDataBanner: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.small) {
            Image(systemName: "sparkles.rectangle.stack")
                .foregroundStyle(DesignSystem.Colors.accent)
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxxSmall) {
                Text("Exploring with sample data")
                    .font(.subheadline.weight(.semibold))
                Text("These entries are examples. Remove them anytime from Settings without touching your own records.")
                    .font(.footnote)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(DesignSystem.Spacing.medium)
        .background(Color(hex: "#EEF2FC"), in: RoundedRectangle(cornerRadius: DesignSystem.Radius.medium))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
                .stroke(DesignSystem.Colors.accent.opacity(0.16))
        }
        .accessibilityElement(children: .combine)
    }

    private var budgetHealth: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            SectionHeader("Budget health", subtitle: topCategories.isEmpty ? "Category limits appear as you add them" : "Your three largest categories this month")
            if topCategories.isEmpty {
                EmptyStateView(
                    systemImage: "chart.bar.xaxis",
                    title: summary.transactionCount == 0 ? "Your first month starts here" : "No categorized spending yet",
                    message: "Add a categorized expense or set a category limit in Budgets.",
                    actionTitle: summary.transactionCount == 0 ? "Add transaction" : "Open Budgets"
                ) {
                    if summary.transactionCount == 0 {
                        showTransactionForm = true
                    } else {
                        appStore.selectedTab = .budgets
                    }
                }
                .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.large))
            } else {
                FinancialSurface(padding: EdgeInsets(top: 8, leading: DesignSystem.Spacing.medium, bottom: 8, trailing: DesignSystem.Spacing.medium)) {
                    ForEach(topCategories) { item in
                        CategoryBudgetRow(category: item.category, spent: item.spent, limit: item.limit, currencyCode: currencyCode, onTap: nil)
                        if item.id != topCategories.last?.id {
                            Divider().overlay(DesignSystem.Colors.divider)
                        }
                    }
                }
            }
        }
    }

    private var spendingSnapshot: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            SectionHeader("Spending snapshot", subtitle: snapshotRange == .month ? "Daily spending in the selected month" : "The last seven days") {
                Picker("Snapshot range", selection: $snapshotRange) {
                    ForEach(SnapshotRange.allCases) { range in
                        Text(range.title).tag(range)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            if snapshotPoints.isEmpty {
                EmptyStateView(
                    systemImage: "chart.line.uptrend.xyaxis",
                    title: "No spending to chart",
                    message: "Add an expense to see your daily pattern."
                )
                .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.large))
            } else {
                FinancialSurface {
                    Chart(snapshotPoints) { point in
                        AreaMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Spending", point.amount)
                        )
                        .foregroundStyle(DesignSystem.Colors.accent.opacity(0.16).gradient)
                        LineMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Spending", point.amount)
                        )
                        .foregroundStyle(DesignSystem.Colors.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                        PointMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Spending", point.amount)
                        )
                        .foregroundStyle(DesignSystem.Colors.accent)
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 5)) { value in
                            AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        }
                    }
                    .chartYAxis(.hidden)
                    .frame(height: 180)
                    .accessibilityLabel("Spending over time")
                    .accessibilityValue(Text(snapshotAccessibilitySummary))
                }
            }
        }
    }

    @ViewBuilder
    private var upcomingSection: some View {
        if !upcomingPayments.isEmpty {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                SectionHeader("Upcoming payments", subtitle: "Next 30 days") {
                    Button("See all") {
                        appStore.selectedTab = .subscriptions
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.success)
                }
                FinancialSurface(padding: EdgeInsets(top: 4, leading: DesignSystem.Spacing.medium, bottom: 4, trailing: DesignSystem.Spacing.medium)) {
                    ForEach(upcomingPayments, id: \.id) { subscription in
                        NavigationLink {
                            SubscriptionDetailView(subscription: subscription)
                        } label: {
                            UpcomingPaymentRow(subscription: subscription, currencyCode: subscription.currencyCode, calendar: appStore.calendar)
                        }
                        .buttonStyle(.plain)
                        if subscription.id != upcomingPayments.last?.id {
                            Divider().overlay(DesignSystem.Colors.divider)
                        }
                    }
                }
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            SectionHeader("Recent transactions", subtitle: recentTransactions.isEmpty ? "Your latest activity will appear here" : nil) {
                Button("See all") {
                    appStore.selectedTab = .activity
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.success)
            }
            if recentTransactions.isEmpty {
                EmptyStateView(
                    systemImage: "arrow.left.arrow.right",
                    title: "No activity this month",
                    message: "Record your first expense, income, refund, or transfer.",
                    actionTitle: "Add transaction"
                ) {
                    showTransactionForm = true
                }
                .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.large))
            } else {
                FinancialSurface(padding: EdgeInsets(top: 4, leading: DesignSystem.Spacing.medium, bottom: 4, trailing: DesignSystem.Spacing.medium)) {
                    ForEach(recentTransactions, id: \.id) { transaction in
                        Button {
                            selectedTransaction = transaction
                            showTransactionForm = true
                        } label: {
                            TransactionRow(
                                transaction: transaction,
                                category: visibleCategories.first(where: { $0.id == transaction.categoryID }),
                                currencyCode: currencyCode
                            )
                        }
                        .buttonStyle(.plain)
                        if transaction.id != recentTransactions.last?.id {
                            Divider().overlay(DesignSystem.Colors.divider)
                        }
                    }
                }
            }
        }
    }

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            SectionHeader("Worth knowing", subtitle: "A few signals from your records")
            if insights.isEmpty {
                Text("Add a budget, subscription, or transaction and this space will stay focused on useful observations.")
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                    .padding(.horizontal, DesignSystem.Spacing.small)
            } else {
                FinancialSurface {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                        ForEach(insights.prefix(2)) { insight in
                            InsightCard(insight: insight, currencyCode: currencyCode)
                        }
                    }
                }
            }
        }
    }

    private var snapshotPoints: [OverviewPoint] {
        let start: Date
        let end: Date
        if snapshotRange == .month {
            guard let interval = appStore.calendar.dateInterval(of: .month, for: selectedMonth) else { return [] }
            start = interval.start
            end = interval.end
        } else {
            end = Date()
            start = appStore.calendar.date(byAdding: .day, value: -6, to: appStore.calendar.startOfDay(for: end)) ?? end
        }
        let rangeTransactions = transactions.filter { $0.date >= start && $0.date < end }
        let grouped = Dictionary(grouping: rangeTransactions) { appStore.calendar.startOfDay(for: $0.date) }
        return grouped.keys.sorted().compactMap { date in
            let amount = (grouped[date] ?? []).reduce(Decimal.zero) { $0 + $1.budgetImpactAmount }
            guard amount > .zero else { return nil }
            return OverviewPoint(date: date, amount: NSDecimalNumber(decimal: amount).doubleValue)
        }
    }

    private var snapshotAccessibilitySummary: String {
        guard let point = snapshotPoints.max(by: { $0.amount < $1.amount }) else { return "No spending recorded" }
        return "Highest day was \(point.date.formatted(date: .abbreviated, time: .omitted)) at \(MoneyTextValue.string(Decimal(point.amount), currencyCode: currencyCode))."
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "morning" }
        if hour < 18 { return "afternoon" }
        return "evening"
    }
}

private struct SummaryValue: View {
    let title: String
    let amount: Decimal
    let currencyCode: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxxSmall) {
            Text(title)
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
            MoneyText(amount, currencyCode: currencyCode, font: .subheadline.monospacedDigit().weight(.semibold), color: color)
        }
    }
}

private struct OverviewCategory: Identifiable {
    let category: BudgetCategory
    let spent: Decimal
    let limit: Decimal
    var id: UUID { category.id }
}

private struct OverviewPoint: Identifiable {
    let date: Date
    let amount: Double
    var id: Date { date }
}

private enum SnapshotRange: String, CaseIterable, Identifiable {
    case week
    case month

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

#Preview("Overview · sample data") {
    NavigationStack {
        OverviewView()
    }
    .environmentObject(PreviewSupport.sampleStore)
    .modelContainer(PreviewSupport.sampleContainer)
}
