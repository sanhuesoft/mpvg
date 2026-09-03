//
//  ColorTheme.swift
//  mpvg
//
//  Design system inspired by CaskHub: warm latte/cream palette,
//  soft borders, terracotta accents, and sage green active states.
//

import SwiftUI

enum ColorTheme {
    // Backgrounds
    static let windowBackground = Color(hex: "F6EFE6")
    static let sidebarBackground = Color(hex: "EFE7DC")
    static let cardBackground = Color(hex: "FDFBF7")
    static let cardBorder = Color(hex: "E8DFD3")
    static let cardBorderHover = Color(hex: "D8CCBD")
    
    // Accents
    static let terracotta = Color(hex: "C85A32")
    static let terracottaLight = Color(hex: "EBD5C8")
    static let selectedPill = Color(hex: "EBD5C8")
    static let terracottaHover = Color(hex: "B34C28")
    
    // Status & Badges
    static let sageGreen = Color(hex: "2D6A4F")
    static let sageGreenBg = Color(hex: "DCEDE2")
    static let sageGreenBorder = Color(hex: "B7DAC4")
    
    static let amber = Color(hex: "B07219")
    static let amberBg = Color(hex: "F7ECD8")
    
    static let blue = Color(hex: "2A6496")
    static let blueBg = Color(hex: "E3EEF8")
    
    // Typography Colors
    static let textPrimary = Color(hex: "2D2620")
    static let textSecondary = Color(hex: "776C61")
    static let textTertiary = Color(hex: "A09589")
    
    // Bottom Bar
    static let bottomBarBackground = Color(hex: "EBE3D6")
    static let bottomBarBorder = Color(hex: "DCD1BF")
    
    // Search & Inputs
    static let inputBackground = Color(hex: "FDFBF8")
    static let inputBorder = Color(hex: "E3D9CC")
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
}
