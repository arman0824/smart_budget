import Charts
import SwiftUI
import SwiftData

struct InsightsView: View {
    @EnvironmentObject private var appStore: AppStore
    @Query(sort: \Transaction.date) private var transactions: [Transaction]
    @Query(sort: \Subscription.nextBillingDate) private var subscriptions: [Subscription]
    @Query(sort: \BudgetCategory.sortOrder) private var categories: [BudgetCategory]
    @Query private var budgets: [BudgetPlan]

    @State private var range: InsightRange = .threeMonths

    private var selectedMonth: Date { appStore.selectedMonth }
    private var currencyCode: String { appStore.preferences?.currencyCode ?? "INR" }
    private var categoryNames: [UUID: String] { Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) }) }
    private var interval: DateInterval? { range.interval(around: selectedMonth, calendar: appStore.calendar) }
    private var rangeTransactions: [Transaction] {
        guard let interval else { return [] }
        return transactions.filter { $0.date >= interval.start && $0.date < interval.end }
    }
    private var chartGranularity: InsightChartGranularity {
        switch range {
        case .week, .month:
            return .day
        case .threeMonths, .year:
            return .month
        }
    }
    private var insightBuckets: [InsightBucket] {
        guard let interval else { return [] }

        let starts = bucketStarts(in: interval, granularity: chartGranularity)
        return starts.map { start in
            let nextStart = appStore.calendar.date(
                byAdding: chartGranularity.calendarComponent,
                value: 1,
                to: start
            ) ?? interval.end
            let end = min(nextStart, interval.end)
            let bucketTransactions = rangeTransactions.filter {
                $0.date >= start && $0.date < end
            }

            var income = Decimal.zero
            var expenses = Decimal.zero
            var refunds = Decimal.zero

            for transaction in bucketTransactions {
                let amount = transaction.normalizedAmount
                switch transaction.kind {
                case .income:
                    income += amount
                case .expense:
                    expenses += amount
                case .refund:
                    refunds += amount
                case .transfer:
                    break
                }
            }

            return InsightBucket(
                date: start,
                income: income,
                expenses: expenses,
                refunds: refunds
            )
        }
    }
    private var spendingPoints: [SpendingPoint] {
        insightBuckets.map {
            SpendingPoint(
                date: $0.date,
                amount: $0.spending
            )
        }
    }
    private var cashFlowBars: [CashFlowBar] {
        insightBuckets.flatMap { bucket in
            [
                CashFlowBar(date: bucket.date, kind: .income, amount: bucket.income),
                CashFlowBar(date: bucket.date, kind: .spending, amount: bucket.spending)
            ]
        }
    }
    private var rangeTotals: InsightTotals {
        InsightTotals(
            income: insightBuckets.reduce(Decimal.zero) { $0 + $1.income },
            expenses: insightBuckets.reduce(Decimal.zero) { $0 + $1.expenses },
            refunds: insightBuckets.reduce(Decimal.zero) { $0 + $1.refunds }
        )
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
        .background(DesignSystem.Colors.canvas.ignoresSafeArea())
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
        .controlSize(.large)
    }

    @ViewBuilder
    private var spendingChart: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            SectionHeader(spendingChartTitle, subtitle: range.subtitle)
            if !spendingPoints.contains(where: { $0.amount > .zero }) {
                EmptyStateView(
                    systemImage: "chart.line.uptrend.xyaxis",
                    title: "No net spending yet",
                    message: "Add an expense in this range to see spending by period."
                )
                .financialGlass(
                    in: RoundedRectangle(cornerRadius: DesignSystem.Radius.glass, style: .continuous),
                    tint: DesignSystem.Colors.accent.opacity(0.06)
                )
            } else {
                FinancialSurface {
                    Chart(spendingPoints) { point in
                        BarMark(
                            x: .value("Period", point.date, unit: chartGranularity.calendarComponent),
                            y: .value("Spending", point.amountValue),
                            width: .ratio(chartGranularity == .day ? 0.58 : 0.68)
                        )
                        .foregroundStyle(DesignSystem.Colors.accent.gradient)
                        .cornerRadius(3)
                    }
                    .chartXScale(domain: insightChartDomain)
                    .chartYScale(domain: 0...spendingYMaximum)
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(DesignSystem.Colors.divider)
                            AxisValueLabel(anchor: .leading) {
                                if let amount = value.as(Double.self) {
                                    Text(MoneyTextValue.string(decimalValue(from: amount), currencyCode: currencyCode))
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: spendingAxisDates) { value in
                            AxisValueLabel(anchor: .top) {
                                if let date = value.as(Date.self) {
                                    if chartGranularity == .month {
                                        Text(date, format: .dateTime.month(.abbreviated))
                                    } else {
                                        Text(date, format: .dateTime.day().month(.abbreviated))
                                    }
                                }
                            }
                            .font(.caption2)
                        }
                    }
                    .frame(height: 224)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("Spending chart for \(range.title.lowercased())"))
                    .accessibilityValue(Text(chartAccessibilitySummary))
                }
            }
        }
    }

    @ViewBuilder
    private var incomeSpendingChart: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            SectionHeader("Income versus spending", subtitle: cashFlowChartSubtitle)
            if !cashFlowBars.contains(where: { $0.amount > .zero }) {
                EmptyStateView(
                    systemImage: "arrow.up.arrow.down",
                    title: "No cash flow yet",
                    message: "Add income or spending in this range to compare your cash flow."
                )
                .financialGlass(
                    in: RoundedRectangle(cornerRadius: DesignSystem.Radius.glass, style: .continuous),
                    tint: DesignSystem.Colors.accent.opacity(0.06)
                )
            } else {
                FinancialSurface {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                        cashFlowSummary

                        Chart(cashFlowBars) { bar in
                            BarMark(
                                x: .value("Period", bar.date, unit: chartGranularity.calendarComponent),
                                y: .value("Amount", bar.amountValue),
                                width: .ratio(chartGranularity == .day ? 0.58 : 0.68)
                            )
                            .foregroundStyle(by: .value("Type", bar.kind.rawValue))
                            .position(by: .value("Type", bar.kind.rawValue))
                            .cornerRadius(3)
                        }
                        .chartForegroundStyleScale([
                            CashFlowKind.income.rawValue: DesignSystem.Colors.success,
                            CashFlowKind.spending.rawValue: DesignSystem.Colors.accent
                        ])
                        .chartXScale(domain: insightChartDomain)
                        .chartYScale(domain: 0...cashFlowYMaximum)
                        .chartLegend(position: .bottom, alignment: .leading)
                        .chartYAxis {
                            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                    .foregroundStyle(DesignSystem.Colors.divider)
                                AxisValueLabel(anchor: .leading) {
                                    if let amount = value.as(Double.self) {
                                        Text(MoneyTextValue.string(decimalValue(from: amount), currencyCode: currencyCode))
                                            .font(.caption2)
                                    }
                                }
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: cashFlowAxisDates) { value in
                                AxisValueLabel(anchor: .top) {
                                    if let date = value.as(Date.self) {
                                        if chartGranularity == .month {
                                            Text(date, format: .dateTime.month(.abbreviated))
                                        } else {
                                            Text(date, format: .dateTime.day().month(.abbreviated))
                                        }
                                    }
                                }
                                .font(.caption2)
                            }
                        }
                        .frame(height: 230)
                        .accessibilityLabel("Income versus spending chart")
                        .accessibilityValue(Text(cashFlowAccessibilitySummary))
                    }
                }
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
                            x: .value("Amount", value.amountValue),
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
                    .chartXScale(domain: 0...categoryChartMaximum)
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
                .financialGlass(
                    in: RoundedRectangle(cornerRadius: DesignSystem.Radius.glass, style: .continuous),
                    tint: DesignSystem.Colors.accent.opacity(0.06)
                )
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

    private var spendingChartTitle: String {
        chartGranularity == .day ? "Spending by day" : "Spending by month"
    }

    private var cashFlowChartSubtitle: String {
        chartGranularity == .day ? "Daily cash flow" : "Monthly cash flow"
    }

    private var insightChartDomain: ClosedRange<Date> {
        guard let interval else {
            let end = selectedMonth.addingTimeInterval(86_400)
            return selectedMonth...end
        }
        return interval.start...interval.end
    }

    private var spendingAxisDates: [Date] {
        guard !spendingPoints.isEmpty else { return [] }
        let lastIndex = spendingPoints.count - 1

        switch chartGranularity {
        case .day:
            return spendingPoints.enumerated().compactMap { index, point in
                if range == .week || index == 0 || index.isMultiple(of: 7) || index == lastIndex {
                    return point.date
                }
                return nil
            }
        case .month:
            return insightBuckets.enumerated().compactMap { index, bucket in
                if range == .year && !index.isMultiple(of: 2) && index != lastIndex {
                    return nil
                }
                return bucket.date
            }
        }
    }

    private var cashFlowAxisDates: [Date] {
        spendingAxisDates
    }

    private var spendingYMaximum: Double {
        let maximum = spendingPoints.map(\.amountValue).max() ?? 0
        return max(maximum * 1.15, 1)
    }

    private var cashFlowYMaximum: Double {
        let maximum = cashFlowBars.map(\.amountValue).max() ?? 0
        return max(maximum * 1.15, 1)
    }

    private var categoryChartMaximum: Double {
        let maximum = categoryTotals.map(\.amountValue).max() ?? 0
        return max(maximum * 1.18, 1)
    }

    private var cashFlowSummary: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            cashFlowMetric(title: "Income", amount: rangeTotals.income, color: DesignSystem.Colors.success)
            Divider()
                .frame(height: 34)
            cashFlowMetric(title: "Spending", amount: rangeTotals.spending, color: DesignSystem.Colors.accent)
            Divider()
                .frame(height: 34)
            cashFlowMetric(
                title: "Net",
                amount: rangeTotals.netCashFlow,
                color: rangeTotals.netCashFlow >= .zero ? DesignSystem.Colors.success : DesignSystem.Colors.danger
            )
        }
    }

    private func cashFlowMetric(title: String, amount: Decimal, color: Color) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxxSmall) {
            Text(title)
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
            MoneyText(
                amount,
                currencyCode: currencyCode,
                font: .subheadline.monospacedDigit().weight(.semibold),
                color: color
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bucketStarts(in interval: DateInterval, granularity: InsightChartGranularity) -> [Date] {
        let calendar = appStore.calendar
        let firstStart: Date

        switch granularity {
        case .day:
            firstStart = calendar.startOfDay(for: interval.start)
        case .month:
            firstStart = calendar.dateInterval(of: .month, for: interval.start)?.start ?? interval.start
        }

        var starts: [Date] = []
        var cursor = firstStart
        while cursor < interval.end {
            starts.append(cursor)
            guard let next = calendar.date(byAdding: granularity.calendarComponent, value: 1, to: cursor), next > cursor else {
                break
            }
            cursor = next
        }
        return starts
    }

    private func decimalValue(from amount: Double) -> Decimal {
        NSDecimalNumber(value: amount).decimalValue
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
        guard let highest = spendingPoints.filter({ $0.amount > .zero }).max(by: { $0.amount < $1.amount }) else {
            return "No net spending recorded"
        }
        return "Highest recorded spending was \(MoneyTextValue.string(highest.amount, currencyCode: currencyCode)) on \(highest.date.formatted(date: .abbreviated, time: .omitted))."
    }

    private var cashFlowAccessibilitySummary: String {
        "Income \(MoneyTextValue.string(rangeTotals.income, currencyCode: currencyCode)), spending \(MoneyTextValue.string(rangeTotals.spending, currencyCode: currencyCode)), net \(MoneyTextValue.string(rangeTotals.netCashFlow, currencyCode: currencyCode))."
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

private enum InsightChartGranularity: Equatable {
    case day
    case month

    var calendarComponent: Calendar.Component {
        switch self {
        case .day:
            return .day
        case .month:
            return .month
        }
    }
}

private struct InsightBucket {
    let date: Date
    let income: Decimal
    let expenses: Decimal
    let refunds: Decimal

    var spending: Decimal {
        expenses > refunds ? expenses - refunds : .zero
    }

}

private struct InsightTotals {
    let income: Decimal
    let expenses: Decimal
    let refunds: Decimal

    var spending: Decimal {
        expenses > refunds ? expenses - refunds : .zero
    }

    var netCashFlow: Decimal {
        income + refunds - expenses
    }
}

private enum CashFlowKind: String {
    case income = "Income"
    case spending = "Spending"
}

private struct CashFlowBar: Identifiable {
    let date: Date
    let kind: CashFlowKind
    let amount: Decimal

    var id: String {
        "\(date.timeIntervalSinceReferenceDate)-\(kind.rawValue)"
    }

    var amountValue: Double {
        NSDecimalNumber(decimal: amount).doubleValue
    }
}

private struct SpendingPoint: Identifiable {
    let date: Date
    let amount: Decimal

    var id: Date { date }

    var amountValue: Double {
        NSDecimalNumber(decimal: amount).doubleValue
    }
}

private struct CategoryChartValue: Identifiable {
    let id: UUID
    let name: String
    let amount: Decimal
    let colorHex: String

    var amountValue: Double {
        NSDecimalNumber(decimal: amount).doubleValue
    }
}
