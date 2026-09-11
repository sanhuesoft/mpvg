//
//  ColorTheme.swift
//  mpvg
//
//  Primary Design System (inspired by Cecilia May's Obsidian Primary Theme):
//  - Light Mode: Warm latte & cream palette, biscuit backgrounds, cocoa typography,
//    soft warm borders, and playful terracotta/amber/sage/cyan accents.
//  - Dark Mode: Warm espresso & rich chocolate palette, elevated dark cocoa surfaces,
//    soft biscuit typography (high comfort & legibility), and glowing warm accents.
//

import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

enum PrimaryAccent: String, CaseIterable, Identifiable {
    case terracotta = "terracotta"
    case red = "red"
    case blue = "blue"
    case green = "green"
    case yellow = "yellow"
    case purple = "purple"
    case brown = "brown"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .terracotta: return String(localized: "Terracotta")
        case .red: return String(localized: "Red")
        case .blue: return String(localized: "Blue")
        case .green: return String(localized: "Green")
        case .yellow: return String(localized: "Yellow")
        case .purple: return String(localized: "Purple")
        case .brown: return String(localized: "Brown")
        }
    }
    
    var color: Color {
        switch self {
        case .terracotta:
            return Color.dynamic(light: "D75C28", dark: "EB6A14")
        case .red:
            return Color.dynamic(light: "DF453A", dark: "F7685E")
        case .blue:
            return Color.dynamic(light: "2A90CB", dark: "4DB2D1")
        case .green:
            return Color.dynamic(light: "3EB174", dark: "2EA873")
        case .yellow:
            return Color.dynamic(light: "D79719", dark: "E5AA1F")
        case .purple:
            return Color.dynamic(light: "9B70C3", dark: "9B93DA")
        case .brown:
            return Color.dynamic(light: "9D8062", dark: "D7C0A3")
        }
    }
    
    var lightColor: Color {
        switch self {
        case .terracotta:
            return Color.dynamic(light: "F6E2D5", dark: "432617")
        case .red:
            return Color.dynamic(light: "FCE6E4", dark: "4A1E1B")
        case .blue:
            return Color.dynamic(light: "E1EFF8", dark: "1A3240")
        case .green:
            return Color.dynamic(light: "DCEDE2", dark: "183627")
        case .yellow:
            return Color.dynamic(light: "F9EED7", dark: "382C16")
        case .purple:
            return Color.dynamic(light: "F3EDFA", dark: "2F1F40")
        case .brown:
            return Color.dynamic(light: "EBE3D6", dark: "342C23")
        }
    }
    
    var hoverColor: Color {
        switch self {
        case .terracotta:
            return Color.dynamic(light: "AF3704", dark: "F28238")
        case .red:
            return Color.dynamic(light: "BF3F36", dark: "FB8479")
        case .blue:
            return Color.dynamic(light: "22729B", dark: "6ABFD2")
        case .green:
            return Color.dynamic(light: "329562", dark: "4EC68E")
        case .yellow:
            return Color.dynamic(light: "B67A02", dark: "E2BD60")
        case .purple:
            return Color.dynamic(light: "75509B", dark: "C6A2E1")
        case .brown:
            return Color.dynamic(light: "836B49", dark: "EBDAC6")
        }
    }
}

enum ColorTheme {
    // Backgrounds
    static let windowBackground = Color.dynamic(light: "F8F5F1", dark: "1C1712")
    static let sidebarBackground = Color.dynamic(light: "EEE7DD", dark: "241E18")
    static let cardBackground = Color.dynamic(light: "FCFAF8", dark: "2C241E")
    static let cardBorder = Color.dynamic(light: "E4D7C3", dark: "3D3227")
    static let cardBorderHover = Color.dynamic(light: "CFB696", dark: "5A4938")
    
    // Dynamic Accent based on Primary theme
    static var currentAccent: PrimaryAccent {
        let raw = UserDefaults.standard.string(forKey: "appAccentColor") ?? "terracotta"
        return PrimaryAccent(rawValue: raw) ?? .terracotta
    }
    
    static var accent: Color {
        currentAccent.color
    }
    static var accentLight: Color {
        currentAccent.lightColor
    }
    static var accentHover: Color {
        currentAccent.hoverColor
    }
    
    // Aliases to seamlessly maintain backwards compatibility with existing views
    static var terracotta: Color {
        accent
    }
    static var terracottaLight: Color {
        accentLight
    }
    static let selectedPill = Color.dynamic(light: "F2ECE3", dark: "3B3026")
    static var terracottaHover: Color {
        accentHover
    }
    
    // Status & Badges
    static let sageGreen = Color.dynamic(light: "2D6A4F", dark: "2EA873")
    static let sageGreenBg = Color.dynamic(light: "DCEDE2", dark: "183627")
    static let sageGreenBorder = Color.dynamic(light: "B7DAC4", dark: "2EA873")
    
    static let amber = Color.dynamic(light: "D79719", dark: "E5AA1F")
    static let amberBg = Color.dynamic(light: "F9EED7", dark: "382C16")
    
    static let blue = Color.dynamic(light: "22729B", dark: "4DB2D1")
    static let blueBg = Color.dynamic(light: "E3EEF8", dark: "1A3240")
    
    // Typography Colors
    static let textPrimary = Color.dynamic(light: "432E14", dark: "EBDAC6")
    static let textSecondary = Color.dynamic(light: "836B49", dark: "C7B194")
    static let textTertiary = Color.dynamic(light: "B79D7B", dark: "917959")
    
    // Bottom Bar
    static let bottomBarBackground = Color.dynamic(light: "EEE7DD", dark: "241E18")
    static let bottomBarBorder = Color.dynamic(light: "E4D7C3", dark: "3D3227")
    
    // Search & Inputs
    static let inputBackground = Color.dynamic(light: "FCFAF8", dark: "241E18")
    static let inputBorder = Color.dynamic(light: "E4D7C3", dark: "3D3227")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    static func dynamic(light: String, dark: String) -> Color {
        #if os(macOS)
        return Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            let match = appearance.bestMatch(from: [.aqua, .darkAqua])
            return match == .darkAqua ? NSColor(hex: dark) : NSColor(hex: light)
        }))
        #elseif os(iOS)
        return Color(uiColor: UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
        #else
        return Color(hex: light)
        #endif
    }
}

#if os(macOS)
extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            srgbRed: CGFloat(r) / 255.0,
            green: CGFloat(g) / 255.0,
            blue: CGFloat(b) / 255.0,
            alpha: CGFloat(a) / 255.0
        )
    }
}
#elseif os(iOS)
extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            red: CGFloat(r) / 255.0,
            green: CGFloat(g) / 255.0,
            blue: CGFloat(b) / 255.0,
            alpha: CGFloat(a) / 255.0
        )
    }
}
#endif

struct PrimaryAccentKey: EnvironmentKey {
    static let defaultValue: String = "terracotta"
}

extension EnvironmentValues {
    var primaryAccentName: String {
        get { self[PrimaryAccentKey.self] }
        set { self[PrimaryAccentKey.self] = newValue }
    }
}
