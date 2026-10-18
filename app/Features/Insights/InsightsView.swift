import Charts
import SwiftUI
import SwiftData

struct InsightsView: View {
    @EnvironmentObject private var appStore: AppStore
    @Query(sort: \Transaction.date) private var transactions: [Transaction]
    @Query(sort: \Subscription.nextBillingDate) private var subscriptions: [Subscription]
    @Query(sort: \BudgetCategory.sortOrder) private var categories: [BudgetCategory]
    @Query private var budgets: [BudgetPlan]

    @State private var range: InsightRange = .month

    private var selectedMonth: Date { appStore.selectedMonth }
    private var currencyCode: String { appStore.preferences?.currencyCode ?? "INR" }
    private var categoryNames: [UUID: String] { Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) }) }
    private var interval: DateInterval? { range.interval(around: selectedMonth, calendar: appStore.calendar) }
    private var rangeTransactions: [Transaction] {
        guard let interval else { return [] }
        return transactions.filter { $0.date >= interval.start && $0.date < interval.end }
    }
    private var currentSummary: MonthSummary {
        FinancialCalculator.monthSummary(for: selectedMonth, transactions: transactions, calendar: appStore.calendar)
    }
    private var previousSummary: MonthSummary? {
        guard let previousMonth = appStore.calendar.date(byAdding: .month, value: -1, to: selectedMonth) else { return nil }
        return FinancialCalculator.monthSummary(for: previousMonth, transactions: transactions, calendar: appStore.calendar)
    }
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

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
                header
                rangePicker
                spendingChart
                incomeSpendingChart
                categoryChart
                comparisonSurface
                insightsSection
            }
            .padding(.horizontal, DesignSystem.Spacing.large)
            .padding(.top, DesignSystem.Spacing.small)
            .padding(.bottom, DesignSystem.Spacing.xxLarge)
        }
        .background(DesignSystem.Colors.background.ignoresSafeArea())
        .navigationTitle("Insights")
        .platformLargeNavigationTitle()
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxxSmall) {
                Text("Patterns, not noise")
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                Text("Your financial picture")
                    .font(.title3.weight(.semibold))
            }
            Spacer()
            MonthSelector(month: $appStore.selectedMonth, calendar: appStore.calendar)
        }
    }

    private var rangePicker: some View {
        Picker("Insights range", selection: $range) {
            ForEach(InsightRange.allCases) { range in
                Text(range.title).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var spendingChart: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            SectionHeader("Spending over time", subtitle: range.subtitle)
            if rangeTransactions.filter({ $0.kind == .expense || $0.kind == .refund }).isEmpty {
                EmptyStateView(
                    systemImage: "chart.line.uptrend.xyaxis",
                    title: "Not enough history yet",
                    message: "Add expenses or refunds to see how spending moves over time."
                )
                .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.large))
            } else {
                FinancialSurface {
                    Chart(spendingPoints) { point in
                        BarMark(
                            x: .value("Date", point.date, unit: range == .year ? .month : .day),
                            y: .value("Spending", point.amount)
                        )
                        .foregroundStyle(DesignSystem.Colors.accent.gradient)
                        .cornerRadius(3)
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(DesignSystem.Colors.divider)
                            AxisValueLabel(anchor: .leading) {
                                if let amount = value.as(Decimal.self) {
                                    Text(MoneyTextValue.string(amount, currencyCode: currencyCode))
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: range == .year ? 6 : 5)) { value in
                            AxisValueLabel(anchor: .top) {
                                if let date = value.as(Date.self) {
                                    if range == .year {
                                        Text(date, format: .dateTime.month(.abbreviated))
                                    } else {
                                        Text(date, format: .dateTime.day().month(.abbreviated))
                                    }
                                }
                            }
                            .font(.caption2)
                        }
                    }
                    .frame(height: 210)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("Spending chart for \(range.title.lowercased())"))
                    .accessibilityValue(Text(chartAccessibilitySummary))
                }
            }
        }
    }

    private var incomeSpendingChart: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            SectionHeader("Income versus spending", subtitle: "Monthly cash flow")
            FinancialSurface {
                Chart(monthlyPoints) { point in
                    BarMark(
                        x: .value("Month", point.month, unit: .month),
                        y: .value("Amount", point.income)
                    )
                    .foregroundStyle(DesignSystem.Colors.success)
                    .position(by: .value("Type", "Income"))

                    BarMark(
                        x: .value("Month", point.month, unit: .month),
                        y: .value("Amount", point.spending)
                    )
                    .foregroundStyle(DesignSystem.Colors.accent)
                    .position(by: .value("Type", "Spending"))
                }
                .chartForegroundStyleScale([
                    "Income": DesignSystem.Colors.success,
                    "Spending": DesignSystem.Colors.accent
                ])
                .chartLegend(position: .bottom, alignment: .leading)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(DesignSystem.Colors.divider)
                        AxisValueLabel(anchor: .leading) {
                            if let amount = value.as(Decimal.self) {
                                Text(MoneyTextValue.string(amount, currencyCode: currencyCode))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel(anchor: .top) {
                            if let date = value.as(Date.self) {
                                Text(date, format: .dateTime.month(.abbreviated))
                            }
                        }
                    }
                }
                .frame(height: 210)
                .accessibilityLabel("Income versus spending chart")
                .accessibilityValue(Text(monthlyAccessibilitySummary))
            }
        }
    }

    @ViewBuilder
    private var categoryChart: some View {
        let values = categoryTotals
        if !values.isEmpty {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                SectionHeader("Spending by category", subtitle: "Top categories in the selected range")
                FinancialSurface {
                    Chart(values) { value in
                        BarMark(
                            x: .value("Amount", value.amount),
                            y: .value("Category", value.name)
                        )
                        .foregroundStyle(Color(hex: value.colorHex))
                        .cornerRadius(4)
                        .annotation(position: .trailing, alignment: .center) {
                            Text(MoneyTextValue.string(value.amount, currencyCode: currencyCode))
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(DesignSystem.Colors.secondaryText)
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis {
                        AxisMarks { _ in
                            AxisValueLabel(anchor: .leading)
                        }
                    }
                    .frame(height: CGFloat(max(160, values.count * 42)))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Spending by category")
                    .accessibilityValue(Text(categoryAccessibilitySummary))
                }
            }
        }
    }

    private var comparisonSurface: some View {
        FinancialSurface {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                SectionHeader("Month comparison", subtitle: "Historical observation, not a prediction")
                if let previousSummary, previousSummary.spending > .zero || currentSummary.spending > .zero {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxxSmall) {
                            Text("This month")
                                .font(.caption)
                                .foregroundStyle(DesignSystem.Colors.secondaryText)
                            MoneyText(currentSummary.spending, currencyCode: currencyCode, font: .title3.monospacedDigit().weight(.semibold))
                        }
                        Spacer()
                        Image(systemName: comparisonIcon)
                            .foregroundStyle(comparisonColor)
                        Spacer()
                        VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xxxSmall) {
                            Text("Previous month")
                                .font(.caption)
                                .foregroundStyle(DesignSystem.Colors.secondaryText)
                            MoneyText(previousSummary.spending, currencyCode: currencyCode, font: .title3.monospacedDigit().weight(.semibold))
                        }
                    }
                    Text(comparisonText)
                        .font(.subheadline)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Add activity in two months to see a meaningful comparison.")
                        .font(.subheadline)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                }
            }
        }
    }

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            SectionHeader("Smart observations", subtitle: "Calculated from your local records")
            if insights.isEmpty {
                EmptyStateView(
                    systemImage: "lightbulb",
                    title: "Insights will appear here",
                    message: "Set a category limit or add a subscription to create a useful observation."
                )
                .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.large))
            } else {
                FinancialSurface {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                        ForEach(insights.prefix(3)) { insight in
                            InsightCard(insight: insight, currencyCode: currencyCode)
                            if insight.id != insights.prefix(3).last?.id {
                                Divider().overlay(DesignSystem.Colors.divider)
                            }
                        }
                    }
                }
            }
        }
    }

    private var spendingPoints: [SpendingPoint] {
        guard interval != nil else { return [] }
        let grouped = Dictionary(grouping: rangeTransactions) { transaction in
            range == .year
                ? appStore.calendar.dateInterval(of: .month, for: transaction.date)?.start ?? transaction.date
                : appStore.calendar.startOfDay(for: transaction.date)
        }
        return grouped.keys.sorted().compactMap { date in
            let amount = (grouped[date] ?? []).reduce(Decimal.zero) { total, transaction in
                total + transaction.budgetImpactAmount
            }
            return amount > .zero ? SpendingPoint(date: date, amount: amount) : nil
        }
    }

    private var categoryTotals: [CategoryChartValue] {
        var totals: [UUID: Decimal] = [:]
        for transaction in rangeTransactions {
            guard let categoryID = transaction.categoryID else { continue }
            totals[categoryID, default: .zero] += transaction.budgetImpactAmount
        }
        return totals
            .filter { $0.value > .zero }
            .compactMap { categoryID, amount in
                guard let category = categories.first(where: { $0.id == categoryID }) else { return nil }
                return CategoryChartValue(id: category.id, name: category.name, amount: amount, colorHex: category.colorHex)
            }
            .sorted { $0.amount > $1.amount }
            .prefix(6)
            .map { $0 }
    }

    private var monthlyPoints: [MonthlyPoint] {
        guard let interval else { return [] }
        let start = appStore.calendar.dateInterval(of: .month, for: interval.start)?.start ?? interval.start
        let end = interval.end
        var dates: [Date] = []
        var cursor = start
        while cursor < end, dates.count < 24 {
            dates.append(cursor)
            guard let next = appStore.calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
        }
        return dates.map { month in
            let summary = FinancialCalculator.monthSummary(for: month, transactions: transactions, calendar: appStore.calendar)
            return MonthlyPoint(month: month, income: summary.income, spending: summary.spending)
        }
    }

    private var comparisonText: String {
        guard let previousSummary else { return "There is not enough comparable history yet." }
        guard previousSummary.spending > .zero else {
            return currentSummary.spending > .zero ? "This is the first month with recorded spending." : "No spending is recorded in either month."
        }
        let change = (currentSummary.spending - previousSummary.spending) / previousSummary.spending
        let percent = abs(NSDecimalNumber(decimal: change * 100).doubleValue).formatted(.number.precision(.fractionLength(0)))
        return change > .zero ? "Spending is up \(percent)% compared with last month." : change < .zero ? "Spending is down \(percent)% compared with last month." : "Spending is unchanged compared with last month."
    }

    private var comparisonIcon: String {
        guard let previousSummary else { return "minus" }
        if currentSummary.spending > previousSummary.spending { return "arrow.up.right" }
        if currentSummary.spending < previousSummary.spending { return "arrow.down.right" }
        return "equal"
    }

    private var comparisonColor: Color {
        guard let previousSummary else { return DesignSystem.Colors.secondaryText }
        if currentSummary.spending > previousSummary.spending { return DesignSystem.Colors.danger }
        if currentSummary.spending < previousSummary.spending { return DesignSystem.Colors.success }
        return DesignSystem.Colors.secondaryText
    }

    private var chartAccessibilitySummary: String {
        guard let highest = spendingPoints.max(by: { $0.amount < $1.amount }) else { return "No spending recorded" }
        return "Highest recorded spending was \(MoneyTextValue.string(highest.amount, currencyCode: currencyCode)) on \(highest.date.formatted(date: .abbreviated, time: .omitted))."
    }

    private var monthlyAccessibilitySummary: String {
        monthlyPoints.map { point in
            "\(point.month.formatted(.dateTime.month(.abbreviated).year())), income \(MoneyTextValue.string(point.income, currencyCode: currencyCode)), spending \(MoneyTextValue.string(point.spending, currencyCode: currencyCode))"
        }.joined(separator: ". ")
    }

    private var categoryAccessibilitySummary: String {
        categoryTotals.map { "\($0.name) \(MoneyTextValue.string($0.amount, currencyCode: currencyCode))" }.joined(separator: ", ")
    }
}

private enum InsightRange: String, CaseIterable, Identifiable {
    case week
    case month
    case threeMonths
    case year

    var id: String { rawValue }
    var title: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .threeMonths: return "3 months"
        case .year: return "Year"
        }
    }
    var subtitle: String {
        switch self {
        case .week: return "Last seven days"
        case .month: return "Selected month"
        case .threeMonths: return "Selected month and two before it"
        case .year: return "Selected calendar year"
        }
    }

    func interval(around date: Date, calendar: Calendar) -> DateInterval? {
        switch self {
        case .week:
            let end = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            let start = calendar.date(byAdding: .day, value: -6, to: end) ?? end
            return DateInterval(start: calendar.startOfDay(for: start), end: calendar.startOfDay(for: end))
        case .month:
            return calendar.dateInterval(of: .month, for: date)
        case .threeMonths:
            guard let monthStart = calendar.dateInterval(of: .month, for: date)?.start,
                  let start = calendar.date(byAdding: .month, value: -2, to: monthStart),
                  let end = calendar.date(byAdding: .month, value: 1, to: monthStart)
            else { return nil }
            return DateInterval(start: start, end: end)
        case .year:
            return calendar.dateInterval(of: .year, for: date)
        }
    }
}

private struct SpendingPoint: Identifiable {
    let date: Date
    let amount: Decimal
    var id: Date { date }
}

private struct CategoryChartValue: Identifiable {
    let id: UUID
    let name: String
    let amount: Decimal
    let colorHex: String
}

private struct MonthlyPoint: Identifiable {
    let month: Date
    let income: Decimal
    let spending: Decimal
    var id: Date { month }
}
