import Foundation

struct ExtractedPalette: Identifiable, Codable {
    let id = UUID()
    var colors: [PaletteColor]
    let createdAt: Date
    /// The colors this palette was originally extracted from. Generate stays anchored to these
    /// (or to the locked swatches) rather than compounding off its own output, which is what
    /// keeps a long run related to the source photo. Set once per extraction.
    var anchors: [PaletteColor]
    /// How many times Generate has been tapped since extraction. Selects the hue scheme; past
    /// `PaletteGenerator.wideningIteration` the schemes get bolder. Not surfaced in the UI.
    var generation: Int = 0

    init(colors: [PaletteColor], createdAt: Date, anchors: [PaletteColor]? = nil, generation: Int = 0) {
        self.colors = colors
        self.createdAt = createdAt
        self.anchors = anchors ?? colors
        self.generation = generation
    }

    var lockedColors: [PaletteColor] { colors.filter(\.isLocked) }

    private enum CodingKeys: String, CodingKey {
        case colors, createdAt, anchors, generation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let colors = try container.decode([PaletteColor].self, forKey: .colors)
        self.init(
            colors: colors,
            createdAt: try container.decode(Date.self, forKey: .createdAt),
            anchors: try container.decodeIfPresent([PaletteColor].self, forKey: .anchors) ?? colors,
            generation: try container.decodeIfPresent(Int.self, forKey: .generation) ?? 0
        )
    }
}

extension ExtractedPalette {
    /// What a first-time user lands on before they have extracted anything. Uses the brand
    /// palette (vault: Claude Skill.md section 8) so the empty state still shows ColorSense
    /// rather than arbitrary colors.
    static var brandDefault: ExtractedPalette {
        ExtractedPalette(
            colors: [
                PaletteColor(hex: 0xFF6B6B, dominance: 0.30), // Coral
                PaletteColor(hex: 0x4ECDC4, dominance: 0.25), // Teal
                PaletteColor(hex: 0xFFD93D, dominance: 0.20), // Yellow
                PaletteColor(hex: 0x7C6DEB, dominance: 0.15), // Purple
                PaletteColor(hex: 0x2A2C32, dominance: 0.10),
            ],
            createdAt: Date()
        )
    }

    /// A fixed palette for SwiftUI previews and the `-sample-palette` launch argument. These are
    /// the five swatches from the web app's mobile palette view, which makes a screenshot a
    /// direct side-by-side fidelity check.
    static var sample: ExtractedPalette {
        ExtractedPalette(
            colors: [
                PaletteColor(hex: 0x2A2C32, dominance: 0.31),
                PaletteColor(hex: 0xB0ACA1, dominance: 0.24),
                PaletteColor(hex: 0x666770, dominance: 0.18),
                PaletteColor(hex: 0x99ABB3, dominance: 0.15),
                PaletteColor(hex: 0x2D292B, dominance: 0.12),
            ],
            createdAt: Date()
        )
    }
}
