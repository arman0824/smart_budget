import Foundation

public struct MonthSummary: Equatable {
    public let monthStart: Date
    public let monthEnd: Date
    public let income: Decimal
    public let expenses: Decimal
    public let refunds: Decimal
    public let transfers: Decimal
    /// Gross expenses less refunds, clamped to zero for budget presentation.
    public let spending: Decimal
    public let netCashFlow: Decimal
    public let transactionCount: Int
    public let categoryTotals: [UUID: Decimal]

    public init(
        monthStart: Date,
        monthEnd: Date,
        income: Decimal = .zero,
        expenses: Decimal = .zero,
        refunds: Decimal = .zero,
        transfers: Decimal = .zero,
        spending: Decimal = .zero,
        netCashFlow: Decimal = .zero,
        transactionCount: Int = 0,
        categoryTotals: [UUID: Decimal] = [:]
    ) {
        self.monthStart = monthStart
        self.monthEnd = monthEnd
        self.income = income
        self.expenses = expenses
        self.refunds = refunds
        self.transfers = transfers
        self.spending = spending
        self.netCashFlow = netCashFlow
        self.transactionCount = transactionCount
        self.categoryTotals = categoryTotals
    }

    public static func empty(for date: Date) -> MonthSummary {
        MonthSummary(monthStart: date, monthEnd: date)
    }
}

public struct BudgetStatus: Equatable {
    public let planID: UUID
    public let categoryID: UUID
    public let monthStart: Date
    public let limit: Decimal
    public let spent: Decimal
    public let remaining: Decimal
    /// Percentage is expressed as 0...100 and is not capped when over budget.
    public let percentage: Decimal?

    public init(
        planID: UUID,
        categoryID: UUID,
        monthStart: Date,
        limit: Decimal,
        spent: Decimal,
        remaining: Decimal,
        percentage: Decimal?
    ) {
        self.planID = planID
        self.categoryID = categoryID
        self.monthStart = monthStart
        self.limit = limit
        self.spent = spent
        self.remaining = remaining
        self.percentage = percentage
    }

    public var isOverBudget: Bool {
        remaining < Decimal.zero
    }
}

public struct FinancialInsight: Equatable, Identifiable {
    public let kind: FinancialInsightKind
    public let severity: FinancialInsightSeverity
    public let title: String
    public let detail: String
    public let stableKey: String

    public var id: String {
        stableKey
    }

    public init(
        kind: FinancialInsightKind,
        severity: FinancialInsightSeverity,
        title: String,
        detail: String,
        stableKey: String
    ) {
        self.kind = kind
        self.severity = severity
        self.title = title
        self.detail = detail
        self.stableKey = stableKey
    }
}

public enum FinancialCalculator {
    /// Transfers are deliberately excluded from income, expense, refund, and
    /// category totals so moving money between accounts cannot change a budget.
    /// Refunds are stored as positive values and offset expenses in their
    /// category; a refund cannot make a displayed budget total negative.
    public static func monthSummary(
        for month: Date,
        transactions: [Transaction],
        calendar: Calendar = .current
    ) -> MonthSummary {
        guard let interval = monthInterval(containing: month, calendar: calendar) else {
            return .empty(for: month)
        }

        var income = Decimal.zero
        var expenses = Decimal.zero
        var refunds = Decimal.zero
        var transfers = Decimal.zero
        var categoryRawTotals: [UUID: Decimal] = [:]
        var transactionCount = 0

        for transaction in transactions where isDate(
            transaction.date,
            inside: interval
        ) {
            transactionCount += 1
            let amount = absolute(transaction.normalizedAmount)

            switch transaction.kind {
            case .income:
                income += amount
            case .expense:
                expenses += amount
                add(amount, to: transaction.categoryID, in: &categoryRawTotals)
            case .refund:
                refunds += amount
                add(-amount, to: transaction.categoryID, in: &categoryRawTotals)
            case .transfer:
                transfers += amount
            }
        }

        let categoryTotals = categoryRawTotals.mapValues(nonNegative)
        let netSpending = expenses - refunds

        return MonthSummary(
            monthStart: interval.start,
            monthEnd: interval.end,
            income: income,
            expenses: expenses,
            refunds: refunds,
            transfers: transfers,
            spending: nonNegative(netSpending),
            netCashFlow: income + refunds - expenses,
            transactionCount: transactionCount,
            categoryTotals: categoryTotals
        )
    }

    public static func monthSummary(
        transactions: [Transaction],
        for month: Date,
        calendar: Calendar = .current
    ) -> MonthSummary {
        monthSummary(for: month, transactions: transactions, calendar: calendar)
    }

    public nonisolated static func monthInterval(
        containing date: Date,
        calendar: Calendar = .current
    ) -> DateInterval? {
        calendar.dateInterval(of: .month, for: date)
    }

    public static func categoryTotals(
        for transactions: [Transaction],
        in month: Date,
        calendar: Calendar = .current
    ) -> [UUID: Decimal] {
        monthSummary(for: month, transactions: transactions, calendar: calendar).categoryTotals
    }

    public static func budgetPercentage(spent: Decimal, limit: Decimal) -> Decimal? {
        let normalizedLimit = absolute(limit)
        guard normalizedLimit > Decimal.zero else {
            return nil
        }

        let normalizedSpent = nonNegative(spent)
        return normalizedSpent / normalizedLimit * Decimal(100)
    }

    public static func budgetStatus(
        for plan: BudgetPlan,
        transactions: [Transaction],
        calendar: Calendar = .current
    ) -> BudgetStatus {
        let spent = categoryTotals(
            for: transactions,
            in: plan.monthStart,
            calendar: calendar
        )[plan.categoryID] ?? Decimal.zero
        let limit = absolute(plan.limit)

        return BudgetStatus(
            planID: plan.id,
            categoryID: plan.categoryID,
            monthStart: plan.monthStart,
            limit: limit,
            spent: spent,
            remaining: limit - spent,
            percentage: budgetPercentage(spent: spent, limit: limit)
        )
    }

    public static func budgetStatuses(
        for plans: [BudgetPlan],
        transactions: [Transaction],
        calendar: Calendar = .current
    ) -> [BudgetStatus] {
        plans
            .map { budgetStatus(for: $0, transactions: transactions, calendar: calendar) }
            .sorted {
                if $0.monthStart != $1.monthStart {
                    return $0.monthStart < $1.monthStart
                }
                return $0.planID.uuidString < $1.planID.uuidString
            }
    }

    public static func subscriptionMonthlyEquivalent(
        amount: Decimal,
        billingCycle: SubscriptionBillingCycle
    ) -> Decimal {
        let normalizedAmount = absolute(amount)
        switch billingCycle {
        case .weekly:
            return normalizedAmount * Decimal(52) / Decimal(12)
        case .monthly:
            return normalizedAmount
        case .quarterly:
            return normalizedAmount / Decimal(3)
        case .yearly:
            return normalizedAmount / Decimal(12)
        }
    }

    public static func subscriptionAnnualEquivalent(
        amount: Decimal,
        billingCycle: SubscriptionBillingCycle
    ) -> Decimal {
        let normalizedAmount = absolute(amount)
        switch billingCycle {
        case .weekly:
            return normalizedAmount * Decimal(52)
        case .monthly:
            return normalizedAmount * Decimal(12)
        case .quarterly:
            return normalizedAmount * Decimal(4)
        case .yearly:
            return normalizedAmount
        }
    }

    public static func advance(
        date: Date,
        by billingCycle: SubscriptionBillingCycle,
        calendar: Calendar = .current
    ) -> Date? {
        switch billingCycle {
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case .monthly:
            return addingCalendarMonths(1, to: date, calendar: calendar)
        case .quarterly:
            return addingCalendarMonths(3, to: date, calendar: calendar)
        case .yearly:
            return addingCalendarMonths(12, to: date, calendar: calendar)
        }
    }

    public static func nextOccurrence(
        onOrAfter referenceDate: Date,
        startingAt startDate: Date,
        billingCycle: SubscriptionBillingCycle,
        calendar: Calendar = .current
    ) -> Date? {
        nextOccurrence(
            relativeTo: referenceDate,
            startingAt: startDate,
            billingCycle: billingCycle,
            requiresStrictlyLater: false,
            calendar: calendar
        )
    }

    public static func nextOccurrence(
        after referenceDate: Date,
        startingAt startDate: Date,
        billingCycle: SubscriptionBillingCycle,
        calendar: Calendar = .current
    ) -> Date? {
        nextOccurrence(
            relativeTo: referenceDate,
            startingAt: startDate,
            billingCycle: billingCycle,
            requiresStrictlyLater: true,
            calendar: calendar
        )
    }

    /// Cancelled subscriptions are excluded by default. Set
    /// `includeCancelledSubscriptions` only when a historical recurring-cost
    /// view explicitly needs them; paused subscriptions remain excluded.
    public static func deterministicInsights(
        for month: Date,
        transactions: [Transaction],
        budgets: [BudgetPlan] = [],
        subscriptions: [Subscription] = [],
        categoryNames: [UUID: String] = [:],
        includeCancelledSubscriptions: Bool = false,
        calendar: Calendar = .current
    ) -> [FinancialInsight] {
        let summary = monthSummary(for: month, transactions: transactions, calendar: calendar)
        var insights: [FinancialInsight] = []

        let plansForMonth = budgets.filter {
            isSameMonth($0.monthStart, month, calendar: calendar)
        }

        for status in budgetStatuses(
            for: plansForMonth,
            transactions: transactions,
            calendar: calendar
        ) {
            let categoryName = categoryNames[status.categoryID] ?? "Category"
            let amountText = decimalString(status.spent)
            let limitText = decimalString(status.limit)

            if status.isOverBudget {
                insights.append(
                    FinancialInsight(
                        kind: .budgetExceeded,
                        severity: .critical,
                        title: "Budget exceeded",
                        detail: "\(categoryName) has \(amountText) spent against a \(limitText) budget.",
                        stableKey: "budget-exceeded-\(status.planID.uuidString)"
                    )
                )
            } else if let percentage = status.percentage, percentage >= Decimal(80) {
                insights.append(
                    FinancialInsight(
                        kind: .budgetNearLimit,
                        severity: .warning,
                        title: "Budget nearly used",
                        detail: "\(categoryName) is at \(decimalString(percentage))% of its budget.",
                        stableKey: "budget-near-limit-\(status.planID.uuidString)"
                    )
                )
            }
        }

        let recurringSubscriptions = subscriptions.filter {
            $0.status.isBillable || (includeCancelledSubscriptions && $0.status == .cancelled)
        }
        let monthlySubscriptions = recurringSubscriptions.reduce(Decimal.zero) {
            $0 + FinancialCalculator.subscriptionMonthlyEquivalent(
                amount: $1.amount,
                billingCycle: $1.billingCycle
            )
        }

        if monthlySubscriptions > Decimal.zero {
            insights.append(
                FinancialInsight(
                    kind: .subscriptionCost,
                    severity: .info,
                    title: "Recurring subscriptions",
                    detail: "Recurring subscriptions total about \(decimalString(monthlySubscriptions)) per month.",
                    stableKey: "subscriptions-monthly"
                )
            )
        }

        if summary.refunds > Decimal.zero {
            insights.append(
                FinancialInsight(
                    kind: .refundActivity,
                    severity: .info,
                    title: "Refunds received",
                    detail: "Refunds reduced this month's spending by \(decimalString(summary.refunds)).",
                    stableKey: "refunds-\(monthKey(summary.monthStart, calendar: calendar))"
                )
            )
        }

        if summary.netCashFlow < Decimal.zero {
            insights.append(
                FinancialInsight(
                    kind: .negativeCashFlow,
                    severity: .warning,
                    title: "Negative cash flow",
                    detail: "Expenses exceeded income by \(decimalString(absolute(summary.netCashFlow))).",
                    stableKey: "cash-flow-negative-\(monthKey(summary.monthStart, calendar: calendar))"
                )
            )
        } else if summary.netCashFlow > Decimal.zero {
            insights.append(
                FinancialInsight(
                    kind: .positiveCashFlow,
                    severity: .info,
                    title: "Positive cash flow",
                    detail: "Income exceeded expenses by \(decimalString(summary.netCashFlow)).",
                    stableKey: "cash-flow-positive-\(monthKey(summary.monthStart, calendar: calendar))"
                )
            )
        }

        if summary.transactionCount == 0 && insights.isEmpty {
            insights.append(
                FinancialInsight(
                    kind: .noActivity,
                    severity: .info,
                    title: "No activity yet",
                    detail: "Add a transaction to start tracking this month.",
                    stableKey: "no-activity-\(monthKey(summary.monthStart, calendar: calendar))"
                )
            )
        }

        return insights.sorted {
            let leftPriority = insightPriority($0.kind)
            let rightPriority = insightPriority($1.kind)
            if leftPriority != rightPriority {
                return leftPriority < rightPriority
            }
            return $0.stableKey < $1.stableKey
        }
    }

    private static func nextOccurrence(
        relativeTo referenceDate: Date,
        startingAt startDate: Date,
        billingCycle: SubscriptionBillingCycle,
        requiresStrictlyLater: Bool,
        calendar: Calendar
    ) -> Date? {
        if requiresStrictlyLater ? startDate > referenceDate : startDate >= referenceDate {
            return startDate
        }

        var candidate = startDate
        // A bounded loop prevents malformed calendar data from causing an
        // unbounded calculation while still covering centuries of billing dates.
        for _ in 0..<10_000 {
            guard let next = advance(date: candidate, by: billingCycle, calendar: calendar), next > candidate else {
                return nil
            }
            candidate = next
            if requiresStrictlyLater ? candidate > referenceDate : candidate >= referenceDate {
                return candidate
            }
        }

        return nil
    }

    private nonisolated static func add(
        _ amount: Decimal,
        to categoryID: UUID?,
        in totals: inout [UUID: Decimal]
    ) {
        guard let categoryID else {
            return
        }
        totals[categoryID, default: Decimal.zero] += amount
    }

    private nonisolated static func absolute(_ value: Decimal) -> Decimal {
        value < Decimal.zero ? -value : value
    }

    private nonisolated static func nonNegative(_ value: Decimal) -> Decimal {
        value < Decimal.zero ? Decimal.zero : value
    }

    private nonisolated static func decimalString(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }

    private nonisolated static func isSameMonth(
        _ lhs: Date,
        _ rhs: Date,
        calendar: Calendar
    ) -> Bool {
        guard let interval = monthInterval(containing: rhs, calendar: calendar) else {
            return false
        }
        return isDate(lhs, inside: interval)
    }

    private nonisolated static func isDate(_ date: Date, inside interval: DateInterval) -> Bool {
        date >= interval.start && date < interval.end
    }

    private nonisolated static func monthKey(_ date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        let year = components.year.map(String.init) ?? "0000"
        let month = components.month.map { String(format: "%02d", $0) } ?? "00"
        return "\(year)-\(month)"
    }

    /// Advances by calendar months without rolling a month-end date into the
    /// following month. January 31 therefore advances to February 28/29.
    private nonisolated static func addingCalendarMonths(
        _ value: Int,
        to date: Date,
        calendar: Calendar
    ) -> Date? {
        let originalDay = calendar.component(.day, from: date)
        guard let anchor = calendar.date(byAdding: .month, value: value, to: date),
              let targetInterval = calendar.dateInterval(of: .month, for: anchor),
              let lastMoment = calendar.date(byAdding: .day, value: -1, to: targetInterval.end)
        else {
            return nil
        }

        let lastDay = calendar.component(.day, from: lastMoment)
        let targetDay = min(originalDay, lastDay)
        return calendar.date(byAdding: .day, value: targetDay - 1, to: targetInterval.start)
    }

    private nonisolated static func insightPriority(_ kind: FinancialInsightKind) -> Int {
        switch kind {
        case .budgetExceeded:
            return 0
        case .negativeCashFlow:
            return 1
        case .budgetNearLimit:
            return 2
        case .subscriptionCost:
            return 3
        case .refundActivity:
            return 4
        case .positiveCashFlow:
            return 5
        case .noActivity:
            return 6
        }
    }
}
