import SwiftUI
import SwiftData

struct SubscriptionsView: View {
    @EnvironmentObject private var appStore: AppStore
    @Query(sort: \Subscription.nextBillingDate) private var subscriptions: [Subscription]
    @Query(sort: \BudgetCategory.sortOrder) private var categories: [BudgetCategory]

    @State private var filter: SubscriptionFilter = .all
    @State private var searchText = ""
    @State private var showForm = false
    @State private var selectedSubscription: Subscription?

    private var currencyCode: String { appStore.preferences?.currencyCode ?? "INR" }
    private var visibleCategories: [BudgetCategory] { categories.filter { !$0.isArchived } }

    private var visibleSubscriptions: [Subscription] {
        subscriptions
            .filter { subscription in
                switch filter {
                case .all: return true
                case .active: return subscription.status == .active
                case .trial: return subscription.status == .trial
                case .paused: return subscription.status == .paused
                case .cancelled: return subscription.status == .cancelled
                }
            }
            .filter { subscription in
                let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard !query.isEmpty else { return true }
                return subscription.name.lowercased().contains(query)
                    || subscription.merchant.lowercased().contains(query)
                    || subscription.notes.lowercased().contains(query)
                    || subscription.billingCycle.displayName.lowercased().contains(query)
            }
            .sorted { left, right in
                if left.status != right.status { return statusRank(left.status) < statusRank(right.status) }
                switch (left.nextBillingDate, right.nextBillingDate) {
                case let (leftDate?, rightDate?): return leftDate < rightDate
                case (_?, nil): return true
                case (nil, _?): return false
                default: return left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
                }
            }
    }

    private var activeSubscriptions: [Subscription] {
        subscriptions.filter { $0.status == .active }
    }

    private var billableSubscriptions: [Subscription] {
        subscriptions.filter { $0.status == .active }
    }

    private var monthlyCost: Decimal {
        billableSubscriptions
            .filter { $0.currencyCode == currencyCode }
            .reduce(.zero) { $0 + $1.monthlyEquivalent }
    }

    private var annualCost: Decimal {
        billableSubscriptions
            .filter { $0.currencyCode == currencyCode }
            .reduce(.zero) { $0 + $1.annualEquivalent }
    }

    private var upcomingPayments: [Subscription] {
        let now = Date()
        let thirtyDaysFromNow = appStore.calendar.date(byAdding: .day, value: 30, to: now) ?? now
        return subscriptions.filter {
            $0.status.canHaveUpcomingPayment
                && $0.nextBillingDate.map { $0 >= now && $0 <= thirtyDaysFromNow } == true
        }
        .sorted { ($0.nextBillingDate ?? .distantFuture) < ($1.nextBillingDate ?? .distantFuture) }
    }

    private var trialsEndingSoon: [Subscription] {
        let now = Date()
        let thirtyDaysFromNow = appStore.calendar.date(byAdding: .day, value: 30, to: now) ?? now
        return subscriptions.filter {
            $0.status == .trial
                && $0.trialEndDate.map { $0 >= now && $0 <= thirtyDaysFromNow } == true
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
                summarySurface
                filterBar
                subscriptionContent
            }
            .padding(.horizontal, DesignSystem.Spacing.large)
            .padding(.top, DesignSystem.Spacing.small)
            .padding(.bottom, DesignSystem.Spacing.xxLarge)
        }
        .background(DesignSystem.Colors.canvas.ignoresSafeArea())
        .navigationTitle("Subscriptions")
        .platformLargeNavigationTitle()
#if os(iOS)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search subscriptions")
#elseif os(macOS)
        .searchable(text: $searchText, prompt: "Search subscriptions")
#endif
        .toolbar {
            ToolbarItem(placement: .platformTrailing) {
                Button {
                    selectedSubscription = nil
                    showForm = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.glassProminent)
                .accessibilityLabel("Add subscription")
            }
        }
        .sheet(isPresented: $showForm) {
            SubscriptionFormView(subscription: selectedSubscription)
        }
    }

    private var summarySurface: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxxSmall) {
                    Text("Recurring cost")
                        .font(.subheadline)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                    MoneyText(monthlyCost, currencyCode: currencyCode, font: .system(size: 30, design: .rounded).monospacedDigit().weight(.semibold))
#if os(macOS)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
#endif
                    Text("monthly equivalent")
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                }
#if os(macOS)
                .layoutPriority(1)
#endif
                Spacer()
                VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xxxSmall) {
                    Text("Annualized")
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                    MoneyText(annualCost, currencyCode: currencyCode, font: .subheadline.monospacedDigit().weight(.semibold))
#if os(macOS)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
#endif
                    Text("\(activeSubscriptions.count) active")
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                }
#if os(macOS)
                .frame(minWidth: 96, alignment: .trailing)
                .layoutPriority(2)
#endif
            }

            Divider().overlay(DesignSystem.Colors.divider)

            HStack(spacing: DesignSystem.Spacing.large) {
                SummaryMetric(title: "Due in 30 days", value: "\(upcomingPayments.count)", tint: DesignSystem.Colors.warning)
                SummaryMetric(title: "Trials ending soon", value: "\(trialsEndingSoon.count)", tint: DesignSystem.Colors.accent)
                Spacer()
            }

            if subscriptions.contains(where: { $0.currencyCode != currencyCode && $0.status == .active }) {
                Text("The recurring total includes active subscriptions billed in \(currencyCode). Other currencies are shown on their detail screens.")
                    .font(.footnote)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
            }
        }
        .padding(DesignSystem.Spacing.large)
        .background(DesignSystem.Colors.successSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(DesignSystem.Colors.success.opacity(0.18))
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.small) {
                ForEach(SubscriptionFilter.allCases) { filter in
                    FilterChip(title: filter.title, isSelected: self.filter == filter) {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            self.filter = filter
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var subscriptionContent: some View {
        if visibleSubscriptions.isEmpty {
            EmptyStateView(
                systemImage: searchText.isEmpty ? "repeat.circle" : "magnifyingglass",
                title: searchText.isEmpty ? "No subscriptions yet" : "No matching subscriptions",
                message: searchText.isEmpty ? "Add recurring services to see their monthly equivalent and upcoming renewal dates." : "Try a different name or filter.",
                actionTitle: searchText.isEmpty ? "Add subscription" : nil,
                action: searchText.isEmpty ? {
                    selectedSubscription = nil
                    showForm = true
                } : nil
            )
        } else {
            if !upcomingPayments.isEmpty && filter == .all && searchText.isEmpty {
                subscriptionSection("Upcoming payments", subtitle: "The next 30 days", subscriptions: upcomingPayments)
            }
            subscriptionSection("Subscriptions", subtitle: nil, subscriptions: visibleSubscriptions)
        }
    }

    @ViewBuilder
    private func subscriptionSection(_ title: String, subtitle: String?, subscriptions: [Subscription]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            SectionHeader(title, subtitle: subtitle)
            FinancialSurface(padding: EdgeInsets(top: 4, leading: DesignSystem.Spacing.medium, bottom: 4, trailing: DesignSystem.Spacing.medium)) {
                ForEach(subscriptions, id: \.id) { subscription in
                    NavigationLink {
                        SubscriptionDetailView(subscription: subscription)
                    } label: {
                        SubscriptionRow(subscription: subscription, currencyCode: currencyCode)
                    }
                    .buttonStyle(.plain)
                    if subscription.id != subscriptions.last?.id {
                        Divider().overlay(DesignSystem.Colors.divider)
                    }
                }
            }
        }
    }

    private func statusRank(_ status: SubscriptionStatus) -> Int {
        switch status {
        case .active: return 0
        case .trial: return 1
        case .paused: return 2
        case .cancelled: return 3
        }
    }
}

private enum SubscriptionFilter: String, CaseIterable, Identifiable {
    case all
    case active
    case trial
    case paused
    case cancelled

    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: return "All"
        case .active: return "Active"
        case .trial: return "Trials"
        case .paused: return "Paused"
        case .cancelled: return "Cancelled"
        }
    }
}

private struct SummaryMetric: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxxSmall) {
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
            Text(title)
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
        }
    }
}

private struct SubscriptionRow: View {
    let subscription: Subscription
    let currencyCode: String

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            CategoryIconView(
                systemName: "repeat",
                color: subscription.status == .cancelled ? DesignSystem.Colors.secondaryText : DesignSystem.Colors.accent,
                backgroundColor: subscription.status == .cancelled ? DesignSystem.Colors.divider : Color(hex: "#EEF2FC"),
                size: DesignSystem.Size.iconMedium,
                accessibilityLabel: "Subscription"
            )

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxxSmall) {
                HStack(spacing: DesignSystem.Spacing.small) {
                    Text(subscription.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(DesignSystem.Colors.primaryText)
#if os(macOS)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)
#else
                        .lineLimit(1)
#endif
                    StatusPill(title: subscription.status.displayName, color: statusColor, background: statusColor.opacity(0.12))
#if os(macOS)
                        .fixedSize(horizontal: true, vertical: false)
#endif
                }
#if os(macOS)
                .frame(minWidth: 0, alignment: .leading)
#endif
                Text(description)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
#if os(macOS)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
#else
                    .lineLimit(1)
#endif
            }
#if os(macOS)
            .frame(minWidth: 0, alignment: .leading)
            .layoutPriority(1)
#endif

            Spacer(minLength: DesignSystem.Spacing.small)

            VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xxxSmall) {
                MoneyText(subscription.amount, currencyCode: subscription.currencyCode.isEmpty ? currencyCode : subscription.currencyCode, font: .subheadline.monospacedDigit().weight(.semibold))
#if os(macOS)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
#endif
                Text(subscription.billingCycle.displayName)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
#if os(macOS)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
#endif
            }
#if os(macOS)
            .frame(minWidth: 96, alignment: .trailing)
            .layoutPriority(2)
#endif
        }
        .padding(.vertical, DesignSystem.Spacing.small)
        .opacity(subscription.status == .cancelled ? 0.62 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(subscription.name), \(MoneyTextValue.string(subscription.amount, currencyCode: subscription.currencyCode)), \(subscription.status.displayName)"))
    }

    private var description: String {
        if let date = subscription.nextBillingDate {
            return "Next payment \(date.formatted(date: .abbreviated, time: .omitted))"
        }
        return subscription.notes.isEmpty ? subscription.status.displayName : subscription.notes
    }

    private var statusColor: Color {
        switch subscription.status {
        case .active: return DesignSystem.Colors.success
        case .trial: return DesignSystem.Colors.accent
        case .paused: return DesignSystem.Colors.warning
        case .cancelled: return DesignSystem.Colors.secondaryText
        }
    }
}
