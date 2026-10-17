import SwiftUI

struct MonthSelector: View {
    @Binding var month: Date
    let calendar: Calendar

    init(month: Binding<Date>, calendar: Calendar = .current) {
        _month = month
        self.calendar = calendar
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            Button {
                moveMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous month")

            Text(month, format: .dateTime.month(.wide).year())
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.primaryText)
                .frame(minWidth: 130)

            Button {
                moveMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next month")
        }
        .foregroundStyle(DesignSystem.Colors.success)
        .padding(.horizontal, DesignSystem.Spacing.xSmall)
        .padding(.vertical, DesignSystem.Spacing.xxxSmall)
        .background(DesignSystem.Colors.surface, in: Capsule())
        .overlay {
            Capsule().stroke(DesignSystem.Colors.divider)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Selected month")
        .accessibilityValue(Text(month, format: .dateTime.month(.wide).year()))
    }

    private func moveMonth(by value: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: month) else { return }
        withAnimation(.easeInOut(duration: 0.22)) {
            month = newMonth
        }
    }
}

struct TransactionRow: View {
    let transaction: Transaction
    let category: BudgetCategory?
    let currencyCode: String

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            CategoryIconView(
                systemName: category?.iconName ?? iconName,
                color: category.map { Color(hex: $0.colorHex) } ?? DesignSystem.Colors.accent,
                backgroundColor: category.map { Color(hex: $0.colorHex, opacity: 0.12) },
                size: DesignSystem.Size.iconMedium,
                accessibilityLabel: category?.name ?? transaction.kind.displayName
            )

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxxSmall) {
                Text(transaction.merchant.isEmpty ? transaction.kind.displayName : transaction.merchant)
                    .font(.body.weight(.medium))
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                    .lineLimit(1)
                Text(category?.name ?? transaction.kind.displayName)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: DesignSystem.Spacing.small)

            VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xxxSmall) {
                MoneyText(
                    transaction.normalizedAmount,
                    currencyCode: currencyCode,
                    font: .body.monospacedDigit().weight(.semibold),
                    color: amountColor
                )
                Text(transaction.date, format: .dateTime.day().month(.abbreviated))
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.small)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var iconName: String {
        switch transaction.kind {
        case .income: return "arrow.down.left"
        case .refund: return "arrow.uturn.backward"
        case .transfer: return "arrow.left.arrow.right"
        case .expense: return "creditcard"
        }
    }

    private var amountColor: Color {
        switch transaction.kind {
        case .income, .refund: return DesignSystem.Colors.success
        case .expense, .transfer: return DesignSystem.Colors.primaryText
        }
    }

    private var accessibilitySummary: String {
        let name = transaction.merchant.isEmpty ? transaction.kind.displayName : transaction.merchant
        let direction = transaction.kind == .income || transaction.kind == .refund ? "received" : "spent"
        return "\(name), \(direction) \(transaction.normalizedAmount), \(transaction.date.formatted(date: .abbreviated, time: .omitted))"
    }
}

struct UpcomingPaymentRow: View {
    let subscription: Subscription
    let currencyCode: String
    let calendar: Calendar

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            CategoryIconView(
                systemName: "repeat",
                color: DesignSystem.Colors.warning,
                backgroundColor: Color(hex: "#FFF8E9"),
                size: DesignSystem.Size.iconMedium,
                accessibilityLabel: "Subscription"
            )

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxxSmall) {
                Text(subscription.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                    .lineLimit(1)
                if let nextBillingDate = subscription.nextBillingDate {
                    Text(nextBillingDate, format: .dateTime.day().month(.abbreviated).year())
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                } else {
                    Text("No renewal date")
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                }
            }

            Spacer(minLength: DesignSystem.Spacing.small)

            VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xxxSmall) {
                MoneyText(subscription.amount, currencyCode: currencyCode, font: .body.monospacedDigit().weight(.semibold))
                Text(subscription.billingCycle.displayName)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.small)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(paymentAccessibilityLabel)
    }

    private var paymentAccessibilityLabel: String {
        let dateText = subscription.nextBillingDate?.formatted(date: .abbreviated, time: .omitted) ?? "no renewal date"
        return "\(subscription.name), \(subscription.amount) \(currencyCode), due \(dateText)"
    }
}

struct CategoryBudgetRow: View {
    let category: BudgetCategory
    let spent: Decimal
    let limit: Decimal
    let currencyCode: String
    let onTap: (() -> Void)?

    private var percentage: Double {
        guard limit > .zero else { return 0 }
        return NSDecimalNumber(decimal: spent / limit).doubleValue
    }

    private var statusColor: Color {
        if limit <= .zero { return DesignSystem.Colors.secondaryText }
        if spent > limit { return DesignSystem.Colors.danger }
        if percentage >= 0.8 { return DesignSystem.Colors.warning }
        return DesignSystem.Colors.success
    }

    var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                HStack(spacing: DesignSystem.Spacing.small) {
                    CategoryIconView(
                        systemName: category.iconName,
                        color: Color(hex: category.colorHex),
                        size: DesignSystem.Size.iconSmall,
                        accessibilityLabel: category.name
                    )
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxxSmall) {
                        Text(category.name)
                            .font(.body.weight(.medium))
                            .foregroundStyle(DesignSystem.Colors.primaryText)
                        Text(limit > .zero ? "\(percentage.formatted(.percent.precision(.fractionLength(0)))) used" : "No limit set")
                            .font(.caption)
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xxxSmall) {
                        MoneyText(spent, currencyCode: currencyCode, font: .subheadline.monospacedDigit().weight(.semibold))
                        if limit > .zero {
                            MoneyText(limit, currencyCode: currencyCode, font: .caption, color: DesignSystem.Colors.secondaryText)
                        }
                    }
                }

                BudgetProgressBar(
                    progress: percentage,
                    tint: statusColor,
                    accessibilityLabel: "\(category.name) budget"
                )

                if spent > limit, limit > .zero {
                    Text("\(MoneyTextValue.string(spent - limit, currencyCode: currencyCode)) over budget")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(DesignSystem.Colors.danger)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(onTap == nil ? "" : "Double tap to edit this category budget")
    }
}

struct StatusPill: View {
    let title: String
    let color: Color
    let background: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, DesignSystem.Spacing.small)
            .padding(.vertical, DesignSystem.Spacing.xxxSmall)
            .background(background, in: Capsule())
    }
}

struct InsightCard: View {
    let insight: FinancialInsight
    let currencyCode: String

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.medium) {
            Image(systemName: iconName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxxSmall) {
                Text(insight.title)
                    .font(.body.weight(.semibold))
                Text(insight.detail)
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var iconName: String {
        switch insight.kind {
        case .budgetExceeded: return "exclamationmark.triangle"
        case .budgetNearLimit: return "gauge.with.dots.needle.67percent"
        case .subscriptionCost: return "repeat"
        case .refundActivity: return "arrow.uturn.backward"
        case .negativeCashFlow: return "arrow.down.right"
        case .positiveCashFlow: return "arrow.up.right"
        case .noActivity: return "sparkles"
        }
    }

    private var color: Color {
        switch insight.severity {
        case .critical: return DesignSystem.Colors.danger
        case .warning: return DesignSystem.Colors.warning
        case .info: return DesignSystem.Colors.success
        }
    }
}

enum MoneyTextValue {
    static func string(_ amount: Decimal, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = Locale(identifier: currencyCode == "INR" ? "en_IN" : Locale.current.identifier)
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
    }
}
