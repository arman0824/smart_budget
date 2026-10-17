import Foundation

public enum TransactionKind: String, CaseIterable, Codable, Sendable {
    case expense
    case income
    case refund
    case transfer

    public var displayName: String {
        switch self {
        case .expense:
            return "Expense"
        case .income:
            return "Income"
        case .refund:
            return "Refund"
        case .transfer:
            return "Transfer"
        }
    }

    /// Transactions are stored with a non-negative amount. This multiplier is
    /// used for cash-flow calculations after the transaction kind is applied.
    public var cashFlowMultiplier: Decimal {
        switch self {
        case .expense:
            return -Decimal(1)
        case .income, .refund:
            return Decimal(1)
        case .transfer:
            return Decimal.zero
        }
    }

    /// A refund offsets spending in its category; income and transfers do not
    /// contribute to a budget category total.
    public var budgetMultiplier: Decimal {
        switch self {
        case .expense:
            return Decimal(1)
        case .refund:
            return -Decimal(1)
        case .income, .transfer:
            return Decimal.zero
        }
    }
}

public enum BudgetCategoryKind: String, CaseIterable, Codable, Sendable {
    case expense
    case income

    public var displayName: String {
        switch self {
        case .expense:
            return "Expense"
        case .income:
            return "Income"
        }
    }
}

public enum SubscriptionBillingCycle: String, CaseIterable, Codable, Sendable {
    case weekly
    case monthly
    case quarterly
    case yearly

    public var displayName: String {
        switch self {
        case .weekly:
            return "Weekly"
        case .monthly:
            return "Monthly"
        case .quarterly:
            return "Quarterly"
        case .yearly:
            return "Yearly"
        }
    }
}

public enum SubscriptionStatus: String, CaseIterable, Codable, Sendable {
    case active
    case trial
    case paused
    case cancelled

    public var displayName: String {
        switch self {
        case .active:
            return "Active"
        case .trial:
            return "Trial"
        case .paused:
            return "Paused"
        case .cancelled:
            return "Cancelled"
        }
    }

    public var isBillable: Bool {
        self == .active
    }

    public var canHaveUpcomingPayment: Bool {
        self == .active || self == .trial
    }
}

public enum FinancialInsightKind: String, CaseIterable, Codable, Sendable {
    case budgetExceeded
    case budgetNearLimit
    case subscriptionCost
    case refundActivity
    case negativeCashFlow
    case positiveCashFlow
    case noActivity
}

public enum FinancialInsightSeverity: String, CaseIterable, Codable, Sendable {
    case info
    case warning
    case critical
}
