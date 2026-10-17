import SwiftUI
import SwiftData

@main
struct MyApp: App {
    private let modelContainer: ModelContainer
    @StateObject private var appStore: AppStore

    init() {
        do {
            let container = try ModelContainerFactory.makeContainer()
            modelContainer = container
            _appStore = StateObject(wrappedValue: AppStore(modelContext: container.mainContext))
        } catch {
            fatalError("Unable to create the local finance store: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
#if os(macOS)
        WindowGroup {
            ContentView()
                .environmentObject(appStore)
                .environment(\.locale, Locale(identifier: appStore.preferences?.localeIdentifier ?? "en_IN"))
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 1200, height: 820)

        Settings {
            SettingsView()
                .environmentObject(appStore)
                .environment(\.locale, Locale(identifier: appStore.preferences?.localeIdentifier ?? "en_IN"))
                .modelContainer(modelContainer)
                .platformSettingsFrame()
        }
#else
        WindowGroup {
            ContentView()
                .environmentObject(appStore)
                .environment(\.locale, Locale(identifier: appStore.preferences?.localeIdentifier ?? "en_IN"))
        }
        .modelContainer(modelContainer)
#endif
    }
}
