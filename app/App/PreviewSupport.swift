import Foundation
import SwiftData

@MainActor
enum PreviewSupport {
    static let container: ModelContainer = {
        do {
            return try ModelContainerFactory.makeContainer(inMemory: true)
        } catch {
            fatalError("Preview container could not be created: \(error.localizedDescription)")
        }
    }()

    static let store = AppStore(modelContext: container.mainContext)

    static let sampleContainer: ModelContainer = {
        do {
            return try ModelContainerFactory.makeContainer(inMemory: true)
        } catch {
            fatalError("Sample preview container could not be created: \(error.localizedDescription)")
        }
    }()

    static let sampleStore: AppStore = {
        let store = AppStore(modelContext: sampleContainer.mainContext)
        let preferences = store.preferences ?? store.makePreferences()
        preferences.hasCompletedOnboarding = true
        preferences.monthlySpendingAllowance = Decimal(40000)
        store.seedSampleData()
        return store
    }()
}
