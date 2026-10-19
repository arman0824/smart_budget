import SwiftUI
import SwiftData

struct OverviewView: View {
    @EnvironmentObject private var appStore: AppStore
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \BudgetCategory.sortOrder) private var categories: [BudgetCategory]
    @Query(sort: \Subscription.nextBillingDate) private var subscriptions: [Subscription]
    @Query private var budgets: [BudgetPlan]

    @State private var showSettings = false
    @State private var showTransactionForm = false
    @State private var selectedTransaction: Transaction?

    private var selectedMonth: Date { appStore.selectedMonth }
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
                upcomingSection
                recentSection
            }
            .padding(.horizontal, DesignSystem.Spacing.large)
            .padding(.top, DesignSystem.Spacing.small)
            .padding(.bottom, DesignSystem.Spacing.xxLarge)
        }
        .background(DesignSystem.Colors.canvas.ignoresSafeArea())
        .navigationTitle("Overview")
        .platformLargeNavigationTitle()
        .toolbar {
            ToolbarItemGroup(placement: .platformTrailing) {
                Button {
                    selectedTransaction = nil
                    showTransactionForm = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.glassProminent)
                .accessibilityLabel("Add transaction")
#if os(macOS)
                SettingsLink {
                    Image(systemName: "gearshape")
                        .accessibilityLabel("Settings")
                }
                .buttonStyle(.glass)
#else
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Settings")
#endif
            }
        }
#if os(iOS)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
#endif
        .sheet(isPresented: $showTransactionForm) {
            TransactionFormView(transaction: selectedTransaction)
        }
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .bottom) {
                headerCopy
                Spacer(minLength: DesignSystem.Spacing.small)
                MonthSelector(month: $appStore.selectedMonth, calendar: appStore.calendar)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                headerCopy
                MonthSelector(month: $appStore.selectedMonth, calendar: appStore.calendar)
            }
        }
    }

    private var headerCopy: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxxSmall) {
            Text("Good \(greeting)")
                .font(.subheadline)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
            Text("A calm view of today")
                .font(.title3.weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.primaryText)
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
        .financialGlass(
            in: RoundedRectangle(cornerRadius: DesignSystem.Radius.medium, style: .continuous),
            tint: DesignSystem.Colors.accent.opacity(0.10)
        )
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var budgetHealth: some View {
        if topCategories.isEmpty && summary.transactionCount == 0 {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                SectionHeader("Budget health", subtitle: topCategories.isEmpty ? "Category limits appear as you add them" : "Your three largest categories this month")
                if topCategories.isEmpty {
                    EmptyStateView(
                        systemImage: "chart.bar.xaxis",
                        title: "No categorized spending yet",
                        message: "Add a categorized expense or set a category limit in Budgets.",
                        actionTitle: "Open Budgets"
                    ) {
                        appStore.selectedTab = .budgets
                    }
                    .financialGlass(
                        in: RoundedRectangle(cornerRadius: DesignSystem.Radius.glass, style: .continuous),
                        tint: DesignSystem.Colors.accent.opacity(0.06)
                    )
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
                .financialGlass(
                    in: RoundedRectangle(cornerRadius: DesignSystem.Radius.glass, style: .continuous),
                    tint: DesignSystem.Colors.accent.opacity(0.06)
                )
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

#Preview("Overview · sample data") {
    NavigationStack {
        OverviewView()
    }
    .environmentObject(PreviewSupport.sampleStore)
    .modelContainer(PreviewSupport.sampleContainer)
}
