import SwiftUI

/// Shared visual tokens for the light financial dashboard experience.
enum DesignSystem {
    enum Colors {
        // The palette intentionally stays quiet: a warm-neutral canvas, deep
        // ink for hierarchy, and one confident green for primary actions.
        // Semantic colors are reserved for status, not decoration.
        static let background = Color(hex: "#F3F7F5")
        static let surface = Color(hex: "#FFFFFF")
        static let surfaceSubtle = Color(hex: "#F8FBFA")
        static let surfaceElevated = Color(hex: "#FBFCFF")
        static let primaryText = Color(hex: "#1F2A2A")
        static let secondaryText = Color(hex: "#687777")
        static let success = Color(hex: "#1D7A59")
        static let successSurface = Color(hex: "#E8F4EE")
        static let accent = Color(hex: "#496DAA")
        static let accentSurface = Color(hex: "#EDF2FB")
        static let warning = Color(hex: "#B7791F")
        static let warningSurface = Color(hex: "#FFF6E6")
        static let danger = Color(hex: "#C85656")
        static let dangerSurface = Color(hex: "#FDEEEE")
        static let divider = Color(hex: "#E1E9E5")
        static let canvas = LinearGradient(
            colors: [
                background,
                Color(hex: "#EEF4FA")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        // Keep glass tints quiet so the system material remains the source of
        // translucency and depth. These colors are only used to reinforce
        // hierarchy and selected states.
        static let glassTint = Color.white.opacity(0.70)
        static let glassOutline = Color(hex: "#D8E4DE")
        static let glassShadow = Color.black.opacity(0.06)
    }

    enum Materials {
        static let regular = Glass.regular
        static let interactive = Glass.regular.interactive()

        static func tinted(_ color: Color?, interactive: Bool = false) -> Glass {
            Glass.regular
                .tint(color)
                .interactive(interactive)
        }
    }

    enum Spacing {
        static let xxxSmall: CGFloat = 4
        static let xxSmall: CGFloat = 6
        static let xSmall: CGFloat = 8
        static let small: CGFloat = 12
        static let medium: CGFloat = 16
        static let large: CGFloat = 20
        static let xLarge: CGFloat = 24
        static let xxLarge: CGFloat = 32
    }

    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let glass: CGFloat = 20
        static let pill: CGFloat = 999
    }

    enum Size {
        static let iconSmall: CGFloat = 32
        static let iconMedium: CGFloat = 40
        static let iconLarge: CGFloat = 48
        static let progressBarHeight: CGFloat = 7
    }

    enum Layout {
        static let contentMaxWidth: CGFloat = 1_060
        static let pageHorizontalPadding: CGFloat = 24
        static let pageTopPadding: CGFloat = 12
        static let pageBottomPadding: CGFloat = 36
        static let sectionSpacing: CGFloat = 24
    }

    enum Motion {
        static let press = Animation.easeOut(duration: 0.14)
    }
}

extension Color {
    /// Creates an sRGB color from `#RGB`, `#RRGGBB`, or `#RRGGBBAA` input.
    ///
    /// Invalid input is intentionally rendered as `.clear` instead of
    /// trapping, which keeps persisted or user-entered theme values safe to
    /// display.
    init(hex: String, opacity: Double = 1.0) {
        var normalized = hex.trimmingCharacters(in: .whitespacesAndNewlines)

        if normalized.hasPrefix("#") {
            normalized.removeFirst()
        } else if normalized.lowercased().hasPrefix("0x") {
            normalized.removeFirst(2)
        }

        switch normalized.count {
        case 3, 4:
            normalized = normalized.map { String($0) + String($0) }.joined()
        case 6, 8:
            break
        default:
            self = .clear
            return
        }

        guard let value = UInt64(normalized, radix: 16) else {
            self = .clear
            return
        }

        let isRGBA = normalized.count == 8
        let redShift: UInt64 = isRGBA ? 24 : 16
        let greenShift: UInt64 = isRGBA ? 16 : 8
        let blueShift: UInt64 = isRGBA ? 8 : 0
        let red = Double((value >> redShift) & 0xFF) / 255
        let green = Double((value >> greenShift) & 0xFF) / 255
        let blue = Double((value >> blueShift) & 0xFF) / 255
        let alpha = isRGBA
            ? Double((value >> 0) & 0xFF) / 255
            : 1
        let clampedOpacity = opacity.isFinite ? min(max(opacity, 0), 1) : 1

        self.init(
            .sRGB,
            red: red,
            green: green,
            blue: blue,
            opacity: alpha * clampedOpacity
        )
    }
}
