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
            sidebar
        } detail: {
            NavigationStack {
                selectedSection
            }
        }
        .navigationSplitViewStyle(.balanced)
#else
        TabView(selection: tabSelectionBinding) {
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

#if os(macOS)
    private var sidebar: some View {
        VStack(spacing: 0) {
            sidebarHeader

            List(selection: selectedSidebarTabBinding) {
                Section("Workspace") {
                    sidebarRow(.overview)
                    sidebarRow(.activity)
                }

                Section("Plan") {
                    sidebarRow(.budgets)
                    sidebarRow(.subscriptions)
                }

                Section("Understand") {
                    sidebarRow(.insights)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(DesignSystem.Colors.background.opacity(0.62))

            sidebarFooter
        }
        .background(DesignSystem.Colors.background.opacity(0.72))
        .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 300)
    }

    private var sidebarHeader: some View {
        Button {
            appStore.selectedTab = .overview
        } label: {
            HStack(spacing: DesignSystem.Spacing.small) {
                Image(systemName: "wallet.pass.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.success)
                    .frame(width: DesignSystem.Size.iconMedium, height: DesignSystem.Size.iconMedium)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxxSmall) {
                    Text("Smart Budget")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                    Text("Local and in control")
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DesignSystem.Spacing.small)
            .padding(.vertical, DesignSystem.Spacing.xSmall)
        }
        .buttonStyle(.glass(DesignSystem.Materials.tinted(DesignSystem.Colors.success.opacity(0.12), interactive: true)))
        .padding(.horizontal, DesignSystem.Spacing.small)
        .padding(.top, DesignSystem.Spacing.small)
        .padding(.bottom, DesignSystem.Spacing.xSmall)
    }

    private func sidebarRow(_ tab: AppTab) -> some View {
        Label(tab.title, systemImage: tab.systemImage)
            .tag(tab)
            .foregroundStyle(DesignSystem.Colors.primaryText)
            .accessibilityLabel(tab.title)
    }

    private var sidebarFooter: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            Image(systemName: "calendar")
                .foregroundStyle(DesignSystem.Colors.accent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxxSmall) {
                Text("Viewing")
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                Text(appStore.selectedMonth, format: .dateTime.month(.wide).year())
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DesignSystem.Spacing.small)
        .padding(.vertical, DesignSystem.Spacing.small)
        .financialGlass(
            in: RoundedRectangle(cornerRadius: DesignSystem.Radius.medium, style: .continuous),
            tint: DesignSystem.Colors.accent.opacity(0.08)
        )
        .padding(.horizontal, DesignSystem.Spacing.small)
        .padding(.bottom, DesignSystem.Spacing.small)
    }
#endif

#if os(macOS)
    private var selectedSidebarTabBinding: Binding<AppTab?> {
        Binding(
            get: { appStore.selectedTab },
            set: { selectedTab in
                if let selectedTab, selectedTab != appStore.selectedTab {
                    appStore.selectedTab = selectedTab
                }
            }
        )
    }
#endif

    private var tabSelectionBinding: Binding<AppTab> {
        Binding(
            get: { appStore.selectedTab },
            set: { selectedTab in
                if selectedTab != appStore.selectedTab {
                    appStore.selectedTab = selectedTab
                }
            }
        )
    }

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
