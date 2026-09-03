import Foundation

/// The four starting points offered in onboarding's second beat.
///
/// These exist so a first-time reader's opening move *produces a palette they chose* rather than
/// dismissing a description of one. Picking a mood recolors the live bands behind the card
/// immediately, which is the whole point: the choice is visible in the product, not banked for
/// later.
///
/// The hexes are onboarding content, not brand values — they are deliberately not in
/// `BrandColor`, which owns the vault's brand kit and nothing else. Each mood is a five-step
/// dark-to-light ramp, so it reads as a designed palette the moment it fills the screen and gives
/// the contrast lesson something honest to work with later.
enum OnboardingMood: String, CaseIterable, Identifiable {
    case warm
    case calm
    case bold
    case earthy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .warm: return "Warm"
        case .calm: return "Calm"
        case .bold: return "Bold"
        case .earthy: return "Earthy"
        }
    }

    var summary: String {
        switch self {
        case .warm: return "Sunset, terracotta, low light"
        case .calm: return "Sea glass, slate, quiet blues"
        case .bold: return "High contrast, full saturation"
        case .earthy: return "Moss, clay, unbleached linen"
        }
    }

    var systemImage: String {
        switch self {
        case .warm: return "sun.horizon.fill"
        case .calm: return "water.waves"
        case .bold: return "bolt.fill"
        case .earthy: return "leaf.fill"
        }
    }

    /// Lauma's line when this mood lands. Keeping it per-mood is what makes her feel like she is
    /// reacting to the choice rather than reading a script over the top of it.
    var reaction: String {
        switch self {
        case .warm: return "Oh, that's lovely. Late afternoon light."
        case .calm: return "Nice and quiet. Easy to look at for hours."
        case .bold: return "Bold. I like that you didn't hesitate."
        case .earthy: return "Grounded. These always age well."
        }
    }

    /// How Lauma reacts to this palette. The pose changes with the choice, so the mood picker
    /// reads as her responding to what you picked rather than repeating one stock expression.
    ///
    /// Full-body poses only. The kit's expression busts are framed at the chest, so mixing one in
    /// at the same height makes her jump scale between selections.
    var pose: LaumaPose {
        switch self {
        case .warm: return .delighted
        case .calm: return .standing
        case .bold: return .celebrating
        case .earthy: return .curious
        }
    }

    private var hexes: [UInt32] {
        switch self {
        case .warm: return [0x2E1A16, 0xA33B2A, 0xE8703A, 0xF2B263, 0xFBE8D3]
        case .calm: return [0x16262E, 0x2E5266, 0x6E8898, 0x9FB1BC, 0xD3D0CB]
        case .bold: return [0x0B090A, 0xE5383B, 0xF5B700, 0x00A6A6, 0xF5F3F4]
        case .earthy: return [0x2B2A26, 0x566246, 0xA4B494, 0xCFC5A5, 0xEFE9DC]
        }
    }

    /// Descending like `ExtractedPalette.brandDefault`, so a mood palette carries the same shape
    /// of dominance an extracted one would and nothing downstream has to special-case it.
    var colors: [PaletteColor] {
        let dominances = [0.30, 0.25, 0.20, 0.15, 0.10]
        return zip(hexes, dominances).map { PaletteColor(hex: $0, dominance: $1) }
    }

    var palette: ExtractedPalette {
        ExtractedPalette(colors: colors, createdAt: Date())
    }
}
