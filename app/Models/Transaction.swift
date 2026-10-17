import Foundation
import SwiftData

@Model
public final class Transaction {
    @Attribute(.unique) public var id: UUID
    public var date: Date
    /// Amounts are normalized to a non-negative value. The kind carries the
    /// direction and meaning of the transaction.
    public var amount: Decimal
    public var merchant: String
    public var note: String
    public var paymentMethod: String
    public var categoryID: UUID?
    public var linkedSubscriptionID: UUID?
    public var kindRawValue: String
    public var createdAt: Date
    public var updatedAt: Date
    public var isSampleData: Bool

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        amount: Decimal,
        merchant: String = "",
        note: String = "",
        paymentMethod: String = "",
        categoryID: UUID? = nil,
        linkedSubscriptionID: UUID? = nil,
        kind: TransactionKind = .expense,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isSampleData: Bool = false
    ) {
        self.id = id
        self.date = date
        self.amount = amount < Decimal.zero ? -amount : amount
        self.merchant = merchant
        self.note = note
        self.paymentMethod = paymentMethod
        self.categoryID = categoryID
        self.linkedSubscriptionID = linkedSubscriptionID
        self.kindRawValue = kind.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isSampleData = isSampleData
    }

    public var kind: TransactionKind {
        get { TransactionKind(rawValue: kindRawValue) ?? .expense }
        set { kindRawValue = newValue.rawValue }
    }

    public var normalizedAmount: Decimal {
        amount < Decimal.zero ? -amount : amount
    }

    public var signedCashFlowAmount: Decimal {
        normalizedAmount * kind.cashFlowMultiplier
    }

    public var budgetImpactAmount: Decimal {
        normalizedAmount * kind.budgetMultiplier
    }
}
