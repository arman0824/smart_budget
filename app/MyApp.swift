import SwiftUI
import SwiftData

@main
struct MyApp: App {
    private let modelContainer: ModelContainer
    @StateObject private var appStore: AppStore
    @AppStorage(AppearanceMode.storageKey) private var appearanceRaw = AppearanceMode.system.rawValue

    init() {
        do {
            let container = try ModelContainerFactory.makeContainer()
            modelContainer = container
            _appStore = StateObject(wrappedValue: AppStore(modelContext: container.mainContext))
        } catch {
            fatalError("Unable to create the local finance store: \(error.localizedDescription)")
        }
    }

    private var preferredScheme: ColorScheme? {
        (AppearanceMode(rawValue: appearanceRaw) ?? .system).colorScheme
    }

    private var locale: Locale {
        guard let identifier = appStore.preferences?.localeIdentifier, !identifier.isEmpty else {
            return Locale(identifier: "en_IN")
        }
        return Locale(identifier: identifier)
    }

    var body: some Scene {
#if os(macOS)
        // A single `Window` (rather than a `WindowGroup`) keeps the app to one
        // dashboard window. `defaultLaunchBehavior` guarantees it is presented
        // on launch instead of restoring an empty, window-less session.
        Window("Smart Budget", id: "main") {
            ContentView()
                .environmentObject(appStore)
                .environment(\.locale, locale)
                .preferredColorScheme(preferredScheme)
                .tint(DesignSystem.Colors.success)
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 1200, height: 820)
        .defaultLaunchBehavior(.presented)

        MenuBarExtra("Quick Log", systemImage: "plus.circle.fill") {
            QuickLogView()
                .environmentObject(appStore)
                .environment(\.locale, locale)
                .modelContainer(modelContainer)
                .preferredColorScheme(preferredScheme)
                .tint(DesignSystem.Colors.success)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appStore)
                .environment(\.locale, locale)
                .modelContainer(modelContainer)
                .preferredColorScheme(preferredScheme)
                .tint(DesignSystem.Colors.success)
        }
        .defaultSize(width: 760, height: 640)
#else
        WindowGroup {
            ContentView()
                .environmentObject(appStore)
                .environment(\.locale, locale)
                .preferredColorScheme(preferredScheme)
                .tint(DesignSystem.Colors.success)
        }
        .modelContainer(modelContainer)
#endif
    }
}
