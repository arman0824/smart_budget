import SwiftUI

extension View {
    @ViewBuilder
    func platformDecimalKeyboard() -> some View {
#if os(iOS)
        self.keyboardType(.decimalPad)
#else
        self
#endif
    }

    @ViewBuilder
    func platformURLKeyboard() -> some View {
#if os(iOS)
        self.keyboardType(.URL)
#else
        self
#endif
    }

    @ViewBuilder
    func platformWordsAutocapitalization() -> some View {
#if os(iOS)
        self.textInputAutocapitalization(.words)
#else
        self
#endif
    }

    @ViewBuilder
    func platformNoAutocapitalization() -> some View {
#if os(iOS)
        self.textInputAutocapitalization(.never)
#else
        self
#endif
    }

    @ViewBuilder
    func platformLargeNavigationTitle() -> some View {
#if os(iOS)
        self.navigationBarTitleDisplayMode(.large)
#else
        self
#endif
    }

    @ViewBuilder
    func platformInlineNavigationTitle() -> some View {
#if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
#else
        self
#endif
    }

    @ViewBuilder
    func platformMainWindowFrame() -> some View {
#if os(macOS)
        self.frame(minWidth: 980, idealWidth: 1200, minHeight: 680, idealHeight: 820)
#else
        self
#endif
    }

    @ViewBuilder
    func platformSettingsFrame() -> some View {
#if os(macOS)
        self.frame(minWidth: 720, idealWidth: 780, minHeight: 540, idealHeight: 640)
#else
        self
#endif
    }

    @ViewBuilder
    func platformSheetFrame(
        minWidth: CGFloat,
        idealWidth: CGFloat,
        minHeight: CGFloat,
        idealHeight: CGFloat
    ) -> some View {
#if os(macOS)
        self.frame(
            minWidth: minWidth,
            idealWidth: idealWidth,
            minHeight: minHeight,
            idealHeight: idealHeight
        )
#else
        self
#endif
    }

    @ViewBuilder
    func platformFormLayout() -> some View {
#if os(macOS)
        self
            .formStyle(.grouped)
            .controlSize(.large)
#else
        self
#endif
    }

    @ViewBuilder
    func platformMultilineField(minHeight: CGFloat = 72) -> some View {
#if os(macOS)
        self.frame(minHeight: minHeight)
#else
        self
#endif
    }
}

extension ToolbarItemPlacement {
    static var platformLeading: ToolbarItemPlacement {
#if os(iOS)
        .topBarLeading
#elseif os(macOS)
        .navigation
#else
        .automatic
#endif
    }

    static var platformTrailing: ToolbarItemPlacement {
#if os(iOS)
        .topBarTrailing
#elseif os(macOS)
        .primaryAction
#else
        .automatic
#endif
    }
}

struct MoneyText: View {
    private let amount: Decimal
    private let currencyCode: String
    private let font: Font
    private let weight: Font.Weight?
    private let color: Color

    @Environment(\.locale) private var locale

    init(
        amount: Decimal,
        currencyCode: String,
        font: Font = .body,
        weight: Font.Weight? = nil,
        color: Color = DesignSystem.Colors.primaryText
    ) {
        self.amount = amount
        self.currencyCode = currencyCode
        self.font = font
        self.weight = weight
        self.color = color
    }

    init(
        _ amount: Decimal,
        currencyCode: String,
        font: Font = .body,
        weight: Font.Weight? = nil,
        color: Color = DesignSystem.Colors.primaryText
    ) {
        self.init(
            amount: amount,
            currencyCode: currencyCode,
            font: font,
            weight: weight,
            color: color
        )
    }

    private var normalizedCurrencyCode: String {
        let code = currencyCode.trimmingCharacters(in: .whitespacesAndNewlines)
        return code.isEmpty ? "INR" : code.uppercased()
    }

    private var formattedAmount: Text {
        Text(
            amount,
            format: .currency(code: normalizedCurrencyCode).locale(locale)
        )
    }

    var body: some View {
        formattedAmount
            .font(font)
            .fontWeight(weight)
            .foregroundStyle(color)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(formattedAmount)
    }
}

struct SectionHeader: View {
    private let title: String
    private let subtitle: String?
    private let trailing: AnyView?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = nil
    }

    init<Trailing: View>(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = AnyView(trailing())
    }

    init(title: String, subtitle: String? = nil) {
        self.init(title, subtitle: subtitle)
    }

    init<Trailing: View>(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.init(title, subtitle: subtitle, trailing: trailing)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.small) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxxSmall) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(DesignSystem.Colors.primaryText)

                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
#if os(macOS)
            .layoutPriority(1)
#endif

            Spacer(minLength: DesignSystem.Spacing.small)

            if let trailing {
#if os(macOS)
                trailing.fixedSize(horizontal: true, vertical: false)
#else
                trailing
#endif
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}

struct CategoryIconView: View {
    private let systemName: String
    private let color: Color
    private let backgroundColor: Color?
    private let size: CGFloat
    private let accessibilityLabel: String?

    init(
        systemName: String,
        color: Color = DesignSystem.Colors.accent,
        backgroundColor: Color? = nil,
        size: CGFloat = DesignSystem.Size.iconMedium,
        accessibilityLabel: String? = nil
    ) {
        self.systemName = systemName
        self.color = color
        self.backgroundColor = backgroundColor
        self.size = max(size, DesignSystem.Size.iconSmall)
        self.accessibilityLabel = accessibilityLabel
    }

    init(
        systemName: String,
        tint: Color,
        backgroundColor: Color? = nil,
        size: CGFloat = DesignSystem.Size.iconMedium,
        accessibilityLabel: String? = nil
    ) {
        self.init(
            systemName: systemName,
            color: tint,
            backgroundColor: backgroundColor,
            size: size,
            accessibilityLabel: accessibilityLabel
        )
    }

    init(
        iconName: String,
        color: Color = DesignSystem.Colors.accent,
        backgroundColor: Color? = nil,
        size: CGFloat = DesignSystem.Size.iconMedium,
        accessibilityLabel: String? = nil
    ) {
        self.init(
            systemName: iconName,
            color: color,
            backgroundColor: backgroundColor,
            size: size,
            accessibilityLabel: accessibilityLabel
        )
    }

    private var defaultAccessibilityLabel: String {
        systemName
            .replacingOccurrences(of: ".fill", with: "")
            .replacingOccurrences(of: ".", with: " ")
    }

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(
                backgroundColor ?? color.opacity(0.12),
                in: RoundedRectangle(
                    cornerRadius: size * 0.25,
                    style: .continuous
                )
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(accessibilityLabel ?? defaultAccessibilityLabel))
            .accessibilityAddTraits(.isImage)
    }
}

struct BudgetProgressBar: View {
    private let progress: Double
    private let tint: Color
    private let trackColor: Color
    private let accessibilityLabel: String

    init(
        progress: Double,
        tint: Color = DesignSystem.Colors.success,
        trackColor: Color = DesignSystem.Colors.divider,
        accessibilityLabel: String = "Budget progress"
    ) {
        self.progress = progress
        self.tint = tint
        self.trackColor = trackColor
        self.accessibilityLabel = accessibilityLabel
    }

    private var clampedProgress: CGFloat {
        let finiteProgress = progress.isFinite ? progress : 0
        return CGFloat(min(max(finiteProgress, 0), 1))
    }

    private var percentage: Int {
        Int((clampedProgress * 100).rounded())
    }

    var body: some View {
        GeometryReader { proxy in
            Capsule(style: .continuous)
                .fill(trackColor)
                .overlay(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(tint)
                        .frame(width: proxy.size.width * clampedProgress)
                }
                .clipShape(Capsule(style: .continuous))
        }
        .frame(maxWidth: .infinity)
        .frame(height: DesignSystem.Size.progressBarHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityValue(Text("\(percentage) percent"))
    }
}

struct FinancialSurface<Content: View>: View {
    private let padding: EdgeInsets
    private let cornerRadius: CGFloat
    private let content: Content

    init(
        padding: EdgeInsets = EdgeInsets(
            top: DesignSystem.Spacing.large,
            leading: DesignSystem.Spacing.large,
            bottom: DesignSystem.Spacing.large,
            trailing: DesignSystem.Spacing.large
        ),
        cornerRadius: CGFloat = DesignSystem.Radius.large,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = max(cornerRadius, 0)
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(
                DesignSystem.Colors.surface,
                in: RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(DesignSystem.Colors.divider, lineWidth: 1)
            }
    }
}

struct EmptyStateView: View {
    private let systemImage: String
    private let title: String
    private let message: String?
    private let actionTitle: String?
    private let action: (() -> Void)?

    init(
        systemImage: String = "tray",
        title: String,
        message: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.accent)
                .frame(width: DesignSystem.Size.iconLarge, height: DesignSystem.Size.iconLarge)
                .background(
                    DesignSystem.Colors.successSurface,
                    in: Circle()
                )
                .accessibilityHidden(true)

            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.primaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let message {
                Text(message)
                    .font(.body)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(DesignSystem.Colors.accent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DesignSystem.Spacing.large)
        .padding(.vertical, DesignSystem.Spacing.xLarge)
        .accessibilityElement(children: .contain)
    }
}

struct FilterChip: View {
    private let title: String
    private let isSelected: Bool
    private let systemImage: String?
    private let action: () -> Void

    init(
        title: String,
        isSelected: Bool = false,
        systemImage: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isSelected = isSelected
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.xxSmall) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .accessibilityHidden(true)
                }

                Text(title)
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(
                isSelected
                    ? DesignSystem.Colors.success
                    : DesignSystem.Colors.primaryText
            )
            .padding(.horizontal, DesignSystem.Spacing.medium)
            .padding(.vertical, DesignSystem.Spacing.xSmall)
            .background(
                isSelected
                    ? DesignSystem.Colors.successSurface
                    : DesignSystem.Colors.surface,
                in: Capsule(style: .continuous)
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(
                        isSelected
                            ? DesignSystem.Colors.success
                            : DesignSystem.Colors.divider,
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(isSelected ? "Selected" : "Not selected"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
