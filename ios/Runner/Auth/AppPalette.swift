import SwiftUI

@available(iOS 16.0, *)
struct AppPalette {
    let background: Color
    let surface: Color
    let surfaceVariant: Color
    let border: Color
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let accent: Color
    let onAccent: Color
    let danger: Color
    let shadow: Color
    let isDark: Bool

    static let dark = AppPalette(
        background: Color(hex: 0x121212),
        surface: Color(hex: 0x1E1E1E),
        surfaceVariant: Color(hex: 0x2A2A2A),
        border: Color(hex: 0x424242),
        textPrimary: Color(hex: 0xFFFFFF),
        textSecondary: Color(hex: 0xBDBDBD),
        textTertiary: Color(hex: 0x9E9E9E),
        accent: Color(hex: 0x00E676),
        onAccent: Color(hex: 0x000000),
        danger: Color(hex: 0xFF5252),
        shadow: Color.black.opacity(0.8),
        isDark: true
    )

    static let light = AppPalette(
        background: Color(hex: 0xF5F5F7),
        surface: Color(hex: 0xFFFFFF),
        surfaceVariant: Color(hex: 0xEDEDEF),
        border: Color(hex: 0xE0E0E0),
        textPrimary: Color(hex: 0x121212),
        textSecondary: Color(hex: 0x555555),
        textTertiary: Color(hex: 0x757575),
        accent: Color(hex: 0x00A152),
        onAccent: Color(hex: 0xFFFFFF),
        danger: Color(hex: 0xD32F2F),
        shadow: Color.black.opacity(0.2),
        isDark: false
    )

    static func resolve(_ name: String, system: ColorScheme) -> AppPalette {
        switch name {
        case "light": return .light
        case "dark": return .dark
        default: return system == .dark ? .dark : .light
        }
    }

    var colorScheme: ColorScheme { isDark ? .dark : .light }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
