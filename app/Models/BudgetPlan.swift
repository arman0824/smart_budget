import Foundation
import SwiftData

@Model
public final class BudgetPlan {
    @Attribute(.unique) public var id: UUID
    /// Any date in the target month is accepted. Calculation helpers compare
    /// this value by calendar month rather than requiring a pre-normalized date.
    public var monthStart: Date
    public var categoryID: UUID
    public var limit: Decimal
    public var note: String
    public var isSampleData: Bool

    public init(
        id: UUID = UUID(),
        monthStart: Date,
        categoryID: UUID,
        limit: Decimal,
        note: String = "",
        isSampleData: Bool = false
    ) {
        self.id = id
        self.monthStart = monthStart
        self.categoryID = categoryID
        self.limit = limit < Decimal.zero ? -limit : limit
        self.note = note
        self.isSampleData = isSampleData
    }

    public var amount: Decimal {
        get { limit }
        set { limit = newValue < Decimal.zero ? -newValue : newValue }
    }
}
