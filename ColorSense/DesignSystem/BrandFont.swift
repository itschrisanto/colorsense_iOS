import SwiftUI

/// Display font is Bebas Neue, UI font is DM Sans (vault: Claude Skill.md section 8).
/// The .ttf files are not in this repo yet — see CLAUDE.md "Fonts" for the manual step
/// to add them. Until then these fall back to the closest system font so the app still builds and runs.
enum BrandFont {
    static func display(_ size: CGFloat) -> Font {
        .custom("BebasNeue-Regular", size: size, relativeTo: .largeTitle)
    }

    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .bold, .heavy, .black: name = "DMSans-Bold"
        case .medium, .semibold: name = "DMSans-Medium"
        default: name = "DMSans-Regular"
        }
        return .custom(name, size: size)
    }

    /// Hex codes are set in a monospaced face so digits align down a stack of palette bands,
    /// matching the web app. There is no brand mono, so this is the system monospace on purpose.
    static func mono(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}
