import SwiftUI

/// ColorSense brand palette. Values must match the vault source of truth:
/// "Knowledge Base/Claude Skill.md" section 8. Do not edit these without updating that file too.
enum BrandColor {
    static let coral = Color(hex: 0xFF6B6B)
    static let teal = Color(hex: 0x4ECDC4)
    static let yellow = Color(hex: 0xFFD93D)
    static let purple = Color(hex: 0x7C6DEB)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
