import Foundation
import SwiftData

@MainActor
public enum ModelContainerFactory {
    public static var schema: Schema {
        Schema([
            Transaction.self,
            BudgetCategory.self,
            BudgetPlan.self,
            Subscription.self,
            AppPreferences.self
        ])
    }

    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let modelSchema = schema
        let configuration = ModelConfiguration(
            schema: modelSchema,
            isStoredInMemoryOnly: inMemory
        )
        let container = try ModelContainer(for: modelSchema, configurations: [configuration])
        try seedDefaults(in: container.mainContext)
        return container
    }

    /// Seeds preferences and the default category set only. Transactions are
    /// intentionally never generated during bootstrap.
    ///
    /// Default categories are inserted only into a genuinely new store
    /// (no categories at all). Seeding by "missing name" resurrects categories
    /// the user renamed or deleted on every launch.
    public static func seedDefaults(in context: ModelContext) throws {
        var didChange = false

        let existingCategories = try context.fetch(FetchDescriptor<BudgetCategory>())
        if existingCategories.isEmpty {
            for (index, definition) in BudgetCategory.defaultDefinitions.enumerated() {
                context.insert(
                    BudgetCategory(
                        name: definition.name,
                        iconName: definition.iconName,
                        colorHex: definition.colorHex,
                        kind: definition.kind,
                        sortOrder: index,
                        isDefault: true
                    )
                )
            }
            didChange = true
        }

        let existingPreferences = try context.fetch(FetchDescriptor<AppPreferences>())
        if existingPreferences.isEmpty {
            context.insert(AppPreferences())
            didChange = true
        }

        if didChange {
            try context.save()
        }
    }
}
