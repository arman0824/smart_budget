import SwiftUI

/// Shared visual tokens for the light financial dashboard experience.
enum DesignSystem {
    enum Colors {
        static let background = Color(hex: "#F7F8FA")
        static let surface = Color(hex: "#FFFFFF")
        static let primaryText = Color(hex: "#202733")
        static let secondaryText = Color(hex: "#747D8B")
        static let success = Color(hex: "#258563")
        static let successSurface = Color(hex: "#E8F4EE")
        static let accent = Color(hex: "#6487CE")
        static let warning = Color(hex: "#D5A04A")
        static let danger = Color(hex: "#D96A6A")
        static let divider = Color(hex: "#E9ECF0")
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
        static let pill: CGFloat = 999
    }

    enum Size {
        static let iconSmall: CGFloat = 32
        static let iconMedium: CGFloat = 40
        static let iconLarge: CGFloat = 48
        static let progressBarHeight: CGFloat = 6
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
