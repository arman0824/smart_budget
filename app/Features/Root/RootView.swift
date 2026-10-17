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
    }
}

#Preview("Root") {
    RootView()
        .environmentObject(PreviewSupport.store)
        .modelContainer(PreviewSupport.container)
}
