import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Shared visual tokens for the financial dashboard. Every semantic colour is
/// adaptive so the app follows the system appearance (and the in-app override)
/// without any view needing to know which scheme is active.
enum DesignSystem {
    enum Colors {
        // The palette intentionally stays quiet: a warm-neutral canvas, deep
        // ink for hierarchy, and one confident green for primary actions.
        // Semantic colors are reserved for status, not decoration.
        static let background = adaptive(light: "#F3F7F5", dark: "#0E1513")
        static let surface = adaptive(light: "#FFFFFF", dark: "#17201D")
        static let surfaceSubtle = adaptive(light: "#F8FBFA", dark: "#121A18")
        static let surfaceElevated = adaptive(light: "#FBFCFF", dark: "#1B2522")
        static let primaryText = adaptive(light: "#1F2A2A", dark: "#F1F5F3")
        static let secondaryText = adaptive(light: "#687777", dark: "#9BA9A5")
        static let success = adaptive(light: "#1D7A59", dark: "#46C596")
        static let successSurface = adaptive(light: "#E8F4EE", dark: "#123327")
        static let accent = adaptive(light: "#496DAA", dark: "#8AB0F0")
        static let accentSurface = adaptive(light: "#EDF2FB", dark: "#182740")
        static let warning = adaptive(light: "#B7791F", dark: "#E2AC52")
        static let warningSurface = adaptive(light: "#FFF6E6", dark: "#33280F")
        static let danger = adaptive(light: "#C85656", dark: "#F08A8A")
        static let dangerSurface = adaptive(light: "#FDEEEE", dark: "#3A1B1B")
        static let divider = adaptive(light: "#E1E9E5", dark: "#2A3633")
        static let canvas = LinearGradient(
            colors: [
                background,
                adaptive(light: "#EEF4FA", dark: "#0B1218")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        // Keep glass tints quiet so the system material remains the source of
        // translucency and depth. These colors are only used to reinforce
        // hierarchy and selected states.
        static let glassTint = adaptive(light: "#FFFFFF", dark: "#101917").opacity(0.62)
        static let glassOutline = adaptive(light: "#D8E4DE", dark: "#33423D")
        static let glassShadow = Color.black.opacity(0.10)

        static func adaptive(light: String, dark: String) -> Color {
#if os(macOS)
            Color(nsColor: NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                    || appearance.name.rawValue.lowercased().contains("dark")
                return NSColor(srgbHex: isDark ? dark : light)
            })
#else
            Color(uiColor: UIColor { traits in
                UIColor(srgbHex: traits.userInterfaceStyle == .dark ? dark : light)
            })
#endif
        }
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

/// User-selectable appearance. Stored with `@AppStorage` so the choice applies
/// to the main window, the menu-bar panel, and the Settings scene together.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "appearanceMode"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

private func srgbComponents(from hex: String) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
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
        return (0, 0, 0, 1)
    }

    guard let value = UInt64(normalized, radix: 16) else { return (0, 0, 0, 1) }
    let isRGBA = normalized.count == 8
    let red = CGFloat((value >> (isRGBA ? 24 : 16)) & 0xFF) / 255
    let green = CGFloat((value >> (isRGBA ? 16 : 8)) & 0xFF) / 255
    let blue = CGFloat((value >> (isRGBA ? 8 : 0)) & 0xFF) / 255
    let alpha = isRGBA ? CGFloat(value & 0xFF) / 255 : 1
    return (red, green, blue, alpha)
}

#if os(macOS)
private extension NSColor {
    convenience init(srgbHex hex: String) {
        let components = srgbComponents(from: hex)
        self.init(
            srgbRed: components.red,
            green: components.green,
            blue: components.blue,
            alpha: components.alpha
        )
    }
}
#else
private extension UIColor {
    convenience init(srgbHex hex: String) {
        let components = srgbComponents(from: hex)
        self.init(
            red: components.red,
            green: components.green,
            blue: components.blue,
            alpha: components.alpha
        )
    }
}
#endif

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
