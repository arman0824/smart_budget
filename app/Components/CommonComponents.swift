import SwiftUI

extension View {
    /// Applies the system Liquid Glass material with the visual weight used
    /// across the finance surfaces. The material, rather than a hand-rolled
    /// blur, owns translucency, highlights, and accessibility behavior.
    func financialGlass<S: Shape>(
        in shape: S,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        glassEffect(
            DesignSystem.Materials.tinted(tint, interactive: interactive),
            in: shape
        )
    }

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

    @ViewBuilder
    func platformAmountFieldWidth() -> some View {
#if os(macOS)
        self.frame(minWidth: 180)
#else
        self.frame(minWidth: 110)
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

struct PageScaffold<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignSystem.Layout.sectionSpacing) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DesignSystem.Layout.pageHorizontalPadding)
            .padding(.top, DesignSystem.Layout.pageTopPadding)
            .padding(.bottom, DesignSystem.Layout.pageBottomPadding)
            .frame(maxWidth: DesignSystem.Layout.contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(DesignSystem.Colors.canvas.ignoresSafeArea())
    }
}

struct PageHeader<Trailing: View>: View {
    private let eyebrow: String
    private let title: String
    private let trailing: Trailing

    init(
        _ eyebrow: String,
        title: String,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .bottom, spacing: DesignSystem.Spacing.medium) {
                copy
                Spacer(minLength: DesignSystem.Spacing.small)
                trailing
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                copy
                trailing
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxxSmall) {
            Text(eyebrow)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(DesignSystem.Colors.secondaryText)

            Text(title)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(DesignSystem.Colors.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .layoutPriority(1)
    }
}

extension PageHeader where Trailing == EmptyView {
    init(_ eyebrow: String, title: String) {
        self.init(eyebrow, title: title) {
            EmptyView()
        }
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
            .lineLimit(1)
            .minimumScaleFactor(0.8)
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
            .layoutPriority(1)

            Spacer(minLength: DesignSystem.Spacing.small)

            if let trailing {
                trailing.fixedSize(horizontal: true, vertical: false)
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
    private let style: FinancialSurfaceStyle
    private let padding: EdgeInsets
    private let cornerRadius: CGFloat
    private let content: Content

    init(
        style: FinancialSurfaceStyle = .standard,
        padding: EdgeInsets = EdgeInsets(
            top: DesignSystem.Spacing.large,
            leading: DesignSystem.Spacing.large,
            bottom: DesignSystem.Spacing.large,
            trailing: DesignSystem.Spacing.large
        ),
        cornerRadius: CGFloat = DesignSystem.Radius.glass,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.padding = padding
        self.cornerRadius = max(cornerRadius, 0)
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(surfaceColor, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(DesignSystem.Colors.glassOutline, lineWidth: 1)
            }
            .shadow(
                color: style == .flat ? .clear : DesignSystem.Colors.glassShadow,
                radius: style == .emphasized ? 14 : 8,
                y: style == .emphasized ? 6 : 3
            )
    }

    private var surfaceColor: Color {
        switch style {
        case .standard:
            return DesignSystem.Colors.surface
        case .emphasized:
            return DesignSystem.Colors.surfaceElevated
        case .flat:
            return DesignSystem.Colors.surfaceSubtle
        }
    }
}

enum FinancialSurfaceStyle: Equatable {
    case standard
    case emphasized
    case flat
}

/// Adds a small, interruptible press response to full-width rows that cannot
/// use a native glass button style without creating a nested surface.
struct FinancialPressButtonStyle: ButtonStyle {
    private let isInteractive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(isInteractive: Bool = true) {
        self.isInteractive = isInteractive
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(isInteractive && !reduceMotion && configuration.isPressed ? 0.985 : 1)
            .animation(
                isInteractive && !reduceMotion ? DesignSystem.Motion.press : nil,
                value: configuration.isPressed
            )
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
                .background(DesignSystem.Colors.successSurface, in: Circle())
                .overlay(Circle().stroke(DesignSystem.Colors.success.opacity(0.12), lineWidth: 1))
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
                    .buttonStyle(.glassProminent)
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
        }
        .buttonStyle(FinancialPressButtonStyle())
        .background(
            isSelected ? DesignSystem.Colors.successSurface : DesignSystem.Colors.surface,
            in: Capsule()
        )
        .overlay {
            Capsule()
                .stroke(
                    isSelected ? DesignSystem.Colors.success.opacity(0.22) : DesignSystem.Colors.divider,
                    lineWidth: 1
                )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(isSelected ? "Selected" : "Not selected"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
