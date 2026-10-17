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
    public static func seedDefaults(in context: ModelContext) throws {
        let existingCategories = try context.fetch(FetchDescriptor<BudgetCategory>())
        let existingNames = Set(existingCategories.map { $0.name.lowercased() })
        var insertedDefaults = false

        for (index, definition) in BudgetCategory.defaultDefinitions.enumerated()
            where !existingNames.contains(definition.name.lowercased()) {
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
            insertedDefaults = true
        }

        let existingPreferences = try context.fetch(FetchDescriptor<AppPreferences>())
        if existingPreferences.isEmpty {
            context.insert(AppPreferences())
            insertedDefaults = true
        }

        if insertedDefaults {
            try context.save()
        }
    }
}
