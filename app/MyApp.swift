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
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(appStore)
                .environment(\.locale, Locale(identifier: appStore.preferences?.localeIdentifier ?? "en_IN"))
                .preferredColorScheme(.light)
                .tint(DesignSystem.Colors.success)
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 1200, height: 820)

        MenuBarExtra("Quick Log", systemImage: "plus.circle.fill") {
            QuickLogView()
                .environmentObject(appStore)
                .environment(\.locale, Locale(identifier: appStore.preferences?.localeIdentifier ?? "en_IN"))
                .modelContainer(modelContainer)
                .colorScheme(.light)
                .preferredColorScheme(.light)
                .foregroundStyle(DesignSystem.Colors.primaryText)
                .tint(DesignSystem.Colors.success)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appStore)
                .environment(\.locale, Locale(identifier: appStore.preferences?.localeIdentifier ?? "en_IN"))
                .modelContainer(modelContainer)
                .preferredColorScheme(.light)
                .foregroundStyle(DesignSystem.Colors.primaryText)
        }
        .defaultSize(width: 760, height: 640)
#else
        WindowGroup {
            ContentView()
                .environmentObject(appStore)
                .environment(\.locale, Locale(identifier: appStore.preferences?.localeIdentifier ?? "en_IN"))
                .preferredColorScheme(.light)
                .tint(DesignSystem.Colors.success)
        }
        .modelContainer(modelContainer)
#endif
    }
}
