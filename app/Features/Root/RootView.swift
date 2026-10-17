import SwiftUI
import SwiftData

struct RootView: View {
    @EnvironmentObject private var appStore: AppStore
    @Query private var preferences: [AppPreferences]

    private var hasCompletedOnboarding: Bool {
        preferences.first?.hasCompletedOnboarding == true
    }

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .tint(DesignSystem.Colors.success)
        .preferredColorScheme(.light)
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { appStore.lastError != nil },
                set: { isPresented in
                    if !isPresented {
                        appStore.clearError()
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                appStore.clearError()
            }
        } message: {
            Text(appStore.lastError ?? "Please try again.")
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var appStore: AppStore

    var body: some View {
#if os(macOS)
        NavigationSplitView {
            List(selection: selectedTabBinding) {
                ForEach(navigationTabs, id: \.self) { tab in
                    Label(tab.title, systemImage: tab.systemImage)
                        .tag(tab)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Smart Budget")
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } detail: {
            NavigationStack {
                selectedSection
            }
            .frame(minWidth: 600, maxHeight: .infinity)
        }
#else
        TabView(selection: $appStore.selectedTab) {
            NavigationStack {
                OverviewView()
            }
            .tabItem {
                Label("Overview", systemImage: "house")
            }
            .tag(AppTab.overview)

            NavigationStack {
                ActivityView()
            }
            .tabItem {
                Label("Activity", systemImage: "arrow.left.arrow.right")
            }
            .tag(AppTab.activity)

            NavigationStack {
                BudgetsView()
            }
            .tabItem {
                Label("Budgets", systemImage: "chart.pie")
            }
            .tag(AppTab.budgets)

            NavigationStack {
                SubscriptionsView()
            }
            .tabItem {
                Label("Subscriptions", systemImage: "repeat")
            }
            .tag(AppTab.subscriptions)

            NavigationStack {
                InsightsView()
            }
            .tabItem {
                Label("Insights", systemImage: "chart.xyaxis.line")
            }
            .tag(AppTab.insights)
        }
#endif
    }

    private var navigationTabs: [AppTab] {
        [.overview, .activity, .budgets, .subscriptions, .insights]
    }

#if os(macOS)
    private var selectedTabBinding: Binding<AppTab?> {
        Binding(
            get: { appStore.selectedTab },
            set: { selectedTab in
                if let selectedTab {
                    appStore.selectedTab = selectedTab
                }
            }
        )
    }
#endif

    @ViewBuilder
    private var selectedSection: some View {
        switch appStore.selectedTab {
        case .overview:
            OverviewView()
        case .activity:
            ActivityView()
        case .budgets:
            BudgetsView()
        case .subscriptions:
            SubscriptionsView()
        case .insights:
            InsightsView()
        }
    }
}

private extension AppTab {
    var title: String {
        switch self {
        case .overview:
            "Overview"
        case .activity:
            "Activity"
        case .budgets:
            "Budgets"
        case .subscriptions:
            "Subscriptions"
        case .insights:
            "Insights"
        }
    }

    var systemImage: String {
        switch self {
        case .overview:
            "house"
        case .activity:
            "arrow.left.arrow.right"
        case .budgets:
            "chart.pie"
        case .subscriptions:
            "repeat"
        case .insights:
            "chart.xyaxis.line"
        }
    }
}

#Preview("Root") {
    RootView()
        .environmentObject(PreviewSupport.store)
        .modelContainer(PreviewSupport.container)
}
