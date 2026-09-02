import Testing
import Foundation
@testable import ColorSense

/// Pins the port of `scorePalette()` from the web app's `lib/paletteHealth.ts`.
///
/// The expected values were produced by transcribing that TypeScript independently and running it
/// over the same palettes, rather than by reading them off this implementation — otherwise the
/// test would only prove the Swift agrees with itself. Same discipline as `ColorMathTests`: if a
/// port drifts, these fail rather than the two products quietly disagreeing about one palette.
@Suite("Palette health")
struct PaletteHealthTests {
    private func palette(_ hexes: [String]) -> [PaletteColor] {
        hexes.compactMap { PaletteColor(hexString: $0, dominance: 1 / Double(hexes.count)) }
    }

    private let brandDefault = ["#FF6B6B", "#4ECDC4", "#FFD93D", "#7C6DEB", "#2A2C32"]

    @Test func brandPaletteScoresAsItDoesOnTheWeb() {
        let result = PaletteHealth.score(palette(brandDefault))

        #expect(result.contrast.score == 93)
        #expect(result.harmony.score == 88)
        #expect(result.balance.score == 100)
        #expect(result.vibrancy.score == 94)
        #expect(result.completeness.score == 65)
        #expect(result.overall == 88)
        #expect(result.grade == .a)
    }

    /// The detail strings are shown verbatim, so their formatting is part of the contract — a
    /// stray decimal place or a different separator is a visible divergence from the web.
    @Test func detailStringsMatchTheWebsWording() {
        let result = PaletteHealth.score(palette(brandDefault))

        #expect(result.contrast.detail == "Max contrast: 10.1:1 · 3/10 pairs pass WCAG AA")
        #expect(result.balance.detail == "Lightness range: 18%–71%")
        #expect(result.vibrancy.detail == "Avg saturation: 68% · Peak: 100%")
    }

    /// Two near-identical greys: no chroma, no contrast, and most of the completeness checks
    /// unmet. Guards the low end of every branch at once.
    @Test func aFlatGreyPairScoresPoorly() {
        let result = PaletteHealth.score(palette(["#222222", "#444444"]))

        #expect(result.contrast.score == 21)
        #expect(result.harmony.score == 82)
        #expect(result.balance.score == 30)
        #expect(result.vibrancy.score == 0)
        #expect(result.completeness.score == 35)
        #expect(result.overall == 35)
        #expect(result.grade == .f)
    }

    @Test func aSingleColorCannotBeScored() {
        let result = PaletteHealth.score(palette(["#FF6B6B"]))

        #expect(result.overall == 0)
        #expect(result.grade == .f)
        #expect(result.contrast.detail == "Not enough colors")
    }

    @Test func gradeBoundariesMatchTheWebsThresholds() {
        #expect(PaletteHealth.grade(for: 85) == .a)
        #expect(PaletteHealth.grade(for: 84) == .b)
        #expect(PaletteHealth.grade(for: 70) == .b)
        #expect(PaletteHealth.grade(for: 69) == .c)
        #expect(PaletteHealth.grade(for: 55) == .c)
        #expect(PaletteHealth.grade(for: 54) == .d)
        #expect(PaletteHealth.grade(for: 40) == .d)
        #expect(PaletteHealth.grade(for: 39) == .f)
    }
}
