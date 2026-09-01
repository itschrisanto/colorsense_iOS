import Foundation

struct Harmony: Identifiable {
    var id: String { title }
    let title: String
    let colors: [PaletteColor]
}

/// The four algorithmic harmonies from the web app's `harmoniesFor()` in labColor.ts.
/// These are free for everyone on the web; the AI-generated harmonies there are a separate
/// Pro layer that iOS does not ship yet (no StoreKit — see CLAUDE.md).
enum ColorHarmony {
    /// Rotates hue by `deltaHue` degrees. Near-greys have no meaningful hue to rotate from, so
    /// they are given a visible mid-tone instead — otherwise every harmony chip off a grey
    /// swatch would come back grey. This guard is the web's, thresholds included.
    private static func shift(_ swatch: PaletteColor, by deltaHue: Double, lightnessDelta: Double = 0) -> PaletteColor {
        let hsl = ColorMath.hsl(fromRed: swatch.red, green: swatch.green, blue: swatch.blue)
        let isNearGrey = hsl.saturation < 0.05
        let saturation = isNearGrey ? 0.6 : hsl.saturation
        let lightness = isNearGrey
            ? 0.55
            : min(max(hsl.lightness + lightnessDelta, 0.12), 0.88)

        let rgb = ColorMath.rgb(
            from: .init(hue: hsl.hue + deltaHue, saturation: saturation, lightness: lightness)
        )
        return PaletteColor(red: rgb.red, green: rgb.green, blue: rgb.blue, dominance: 0)
    }

    static func all(for swatch: PaletteColor) -> [Harmony] {
        [
            Harmony(title: "Analogous", colors: [shift(swatch, by: -30), swatch, shift(swatch, by: 30)]),
            Harmony(title: "Complementary", colors: [swatch, shift(swatch, by: 180)]),
            Harmony(title: "Split Complementary", colors: [swatch, shift(swatch, by: 150), shift(swatch, by: 210)]),
            Harmony(title: "Triadic", colors: [swatch, shift(swatch, by: 120), shift(swatch, by: 240)]),
        ]
    }
}
