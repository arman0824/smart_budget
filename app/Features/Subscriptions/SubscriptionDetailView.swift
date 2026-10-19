import SwiftUI
import SwiftData

struct SubscriptionDetailView: View {
    @EnvironmentObject private var appStore: AppStore
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    let subscription: Subscription
    @State private var showEdit = false
    @State private var showDeleteConfirmation = false
    @State private var showChargeForm = false

    private var relatedTransactions: [Transaction] {
        transactions.filter { $0.linkedSubscriptionID == subscription.id }
    }

    var body: some View {
        PageScaffold {
            header
            costSurface
            renewalSurface
            if !relatedTransactions.isEmpty {
                historySection
            } else {
                EmptyStateView(
                    systemImage: "clock.arrow.circlepath",
                    title: "No recorded charges",
                    message: "A renewal date is only a schedule. Record a real charge when it appears in your account.",
                    actionTitle: "Record a charge"
                ) {
                    showChargeForm = true
                }
                .background(DesignSystem.Colors.surfaceSubtle, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.glass, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.glass, style: .continuous)
                        .stroke(DesignSystem.Colors.divider, lineWidth: 1)
                }
            }
        }
        .navigationTitle(subscription.name)
        .platformInlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .platformTrailing) {
                Menu {
                    Button {
                        showEdit = true
                    } label: {
                        Label("Edit subscription", systemImage: "pencil")
                    }
                    Button {
                        toggleStatus()
                    } label: {
                        Label(subscription.status == .paused ? "Resume" : "Pause", systemImage: subscription.status == .paused ? "play" : "pause")
                    }
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete subscription", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Subscription actions")
            }
        }
        .sheet(isPresented: $showEdit) {
            SubscriptionFormView(subscription: subscription)
        }
        .sheet(isPresented: $showChargeForm) {
            TransactionFormView(subscriptionToRecord: subscription)
        }
        .confirmationDialog("Delete this subscription?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                appStore.deleteSubscription(subscription)
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        }
    }

    private var header: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            CategoryIconView(systemName: "repeat", color: DesignSystem.Colors.accent, backgroundColor: Color(hex: "#EEF2FC"), size: 64, accessibilityLabel: "Subscription")
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxxSmall) {
                Text(subscription.merchant.isEmpty ? subscription.name : subscription.merchant)
                    .font(.title2.weight(.semibold))
#if os(macOS)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
#endif
                StatusPill(title: subscription.status.displayName, color: statusColor, background: statusColor.opacity(0.12))
#if os(macOS)
                    .fixedSize(horizontal: true, vertical: false)
#endif
            }
#if os(macOS)
            .frame(minWidth: 0, alignment: .leading)
            .layoutPriority(1)
#endif
            Spacer()
        }
    }

    private var costSurface: some View {
        FinancialSurface {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxxSmall) {
                        Text("Monthly equivalent")
                            .font(.subheadline)
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                        MoneyText(subscription.monthlyEquivalent, currencyCode: subscription.currencyCode, font: .system(size: 30, design: .rounded).monospacedDigit().weight(.semibold))
#if os(macOS)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
#endif
                    }
#if os(macOS)
                    .layoutPriority(1)
#endif
                    Spacer()
                    VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xxxSmall) {
                        Text("Annualized")
                            .font(.caption)
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                        MoneyText(subscription.annualEquivalent, currencyCode: subscription.currencyCode, font: .subheadline.monospacedDigit().weight(.semibold))
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
                Divider().overlay(DesignSystem.Colors.divider)
                HStack {
                    Text("Actual charge")
                        .font(.subheadline)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                    Spacer()
#if os(macOS)
                    HStack(spacing: DesignSystem.Spacing.xxSmall) {
                        MoneyText(subscription.amount, currencyCode: subscription.currencyCode, font: .subheadline.monospacedDigit().weight(.semibold))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                        Text("/ \(subscription.billingCycle.displayName.lowercased())")
                            .font(.caption)
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .frame(minWidth: 128, alignment: .trailing)
                    .layoutPriority(2)
#else
                    MoneyText(subscription.amount, currencyCode: subscription.currencyCode, font: .subheadline.monospacedDigit().weight(.semibold))
                    Text("/ \(subscription.billingCycle.displayName.lowercased())")
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
#endif
                }
            }
        }
    }

    private var renewalSurface: some View {
        FinancialSurface {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                SectionHeader("Renewal details")
                DetailLine(title: "Next billing date", value: subscription.nextBillingDate?.formatted(date: .long, time: .omitted) ?? "Not set")
                DetailLine(title: "Reminder", value: subscription.reminderDaysBefore == 0 ? "Off" : "\(subscription.reminderDaysBefore) days before")
                if let trialEndDate = subscription.trialEndDate {
                    DetailLine(title: "Trial ends", value: trialEndDate.formatted(date: .long, time: .omitted))
                }
                if !subscription.website.isEmpty {
                    DetailLine(title: "Website", value: subscription.website)
                }
                if !subscription.notes.isEmpty {
                    Text(subscription.notes)
                        .font(.subheadline)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button("Record a real charge") {
                    showChargeForm = true
                }
                .buttonStyle(.borderedProminent)
                .tint(DesignSystem.Colors.success)
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            SectionHeader("Renewal history", subtitle: "Only transactions you recorded")
            FinancialSurface(padding: EdgeInsets(top: 4, leading: DesignSystem.Spacing.medium, bottom: 4, trailing: DesignSystem.Spacing.medium)) {
                ForEach(relatedTransactions, id: \.id) { transaction in
                    TransactionRow(transaction: transaction, category: nil, currencyCode: subscription.currencyCode)
                    if transaction.id != relatedTransactions.last?.id {
                        Divider().overlay(DesignSystem.Colors.divider)
                    }
                }
            }
        }
    }

    private var statusColor: Color {
        switch subscription.status {
        case .active: return DesignSystem.Colors.success
        case .trial: return DesignSystem.Colors.accent
        case .paused: return DesignSystem.Colors.warning
        case .cancelled: return DesignSystem.Colors.secondaryText
        }
    }

    private func toggleStatus() {
        subscription.status = subscription.status == .paused ? .active : .paused
        subscription.updatedAt = Date()
        _ = appStore.save()
        appStore.scheduleReminder(for: subscription)
    }
}

private struct DetailLine: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
#if os(macOS)
                .layoutPriority(1)
#endif
            Spacer(minLength: DesignSystem.Spacing.medium)
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(DesignSystem.Colors.primaryText)
                .multilineTextAlignment(.trailing)
#if os(macOS)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minWidth: 140, alignment: .trailing)
                .layoutPriority(2)
#endif
        }
    }
}
