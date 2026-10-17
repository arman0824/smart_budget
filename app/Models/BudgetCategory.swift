import Foundation
import SwiftData

public struct DefaultBudgetCategory: Hashable, Sendable {
    public let name: String
    public let iconName: String
    public let colorHex: String
    public let kind: BudgetCategoryKind

    public init(
        name: String,
        iconName: String,
        colorHex: String,
        kind: BudgetCategoryKind = .expense
    ) {
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.kind = kind
    }
}

@Model
public final class BudgetCategory {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var iconName: String
    public var colorHex: String
    public var kindRawValue: String
    public var sortOrder: Int
    public var isArchived: Bool
    public var isDefault: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        iconName: String = "tag",
        colorHex: String = "#64748B",
        kind: BudgetCategoryKind = .expense,
        sortOrder: Int = 0,
        isArchived: Bool = false,
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.kindRawValue = kind.rawValue
        self.sortOrder = sortOrder
        self.isArchived = isArchived
        self.isDefault = isDefault
    }

    public var kind: BudgetCategoryKind {
        get { BudgetCategoryKind(rawValue: kindRawValue) ?? .expense }
        set { kindRawValue = newValue.rawValue }
    }

    public static let defaultDefinitions: [DefaultBudgetCategory] = [
        DefaultBudgetCategory(name: "Housing", iconName: "house.fill", colorHex: "#4F46E5"),
        DefaultBudgetCategory(name: "Groceries", iconName: "cart.fill", colorHex: "#2F8F6B"),
        DefaultBudgetCategory(name: "Dining", iconName: "fork.knife", colorHex: "#EA580C"),
        DefaultBudgetCategory(name: "Transport", iconName: "car.fill", colorHex: "#0891B2"),
        DefaultBudgetCategory(name: "Bills & utilities", iconName: "bolt.fill", colorHex: "#CA8A04"),
        DefaultBudgetCategory(name: "Shopping", iconName: "bag.fill", colorHex: "#DB2777"),
        DefaultBudgetCategory(name: "Entertainment", iconName: "play.rectangle.fill", colorHex: "#7C3AED"),
        DefaultBudgetCategory(name: "Health", iconName: "heart.fill", colorHex: "#DC2626"),
        DefaultBudgetCategory(name: "Education", iconName: "book.fill", colorHex: "#6487CE"),
        DefaultBudgetCategory(name: "Travel", iconName: "airplane", colorHex: "#0F766E"),
        DefaultBudgetCategory(name: "Personal care", iconName: "sparkles", colorHex: "#C05A82"),
        DefaultBudgetCategory(name: "Other", iconName: "ellipsis.circle.fill", colorHex: "#64748B")
    ]
}
