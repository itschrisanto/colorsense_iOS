import Testing
@testable import ColorSense

struct ContrastCalculatorTests {
    @Test func blackOnWhiteIsMaxContrast() {
        let ratio = ContrastCalculator.ratio(r1: 0, g1: 0, b1: 0, r2: 1, g2: 1, b2: 1)
        #expect(abs(ratio - 21.0) < 0.01)
    }

    @Test func sameColorIsMinContrast() {
        let ratio = ContrastCalculator.ratio(r1: 0.4, g1: 0.4, b1: 0.4, r2: 0.4, g2: 0.4, b2: 0.4)
        #expect(abs(ratio - 1.0) < 0.001)
    }

    @Test func orderOfArgumentsDoesNotMatter() {
        let a = ContrastCalculator.ratio(r1: 0, g1: 0, b1: 0, r2: 1, g2: 1, b2: 1)
        let b = ContrastCalculator.ratio(r1: 1, g1: 1, b1: 1, r2: 0, g2: 0, b2: 0)
        #expect(a == b)
    }

    @Test func normalTextThresholds() {
        #expect(ContrastCalculator.normalTextLevel(for: 7.0) == .aaa)
        #expect(ContrastCalculator.normalTextLevel(for: 4.5) == .aa)
        #expect(ContrastCalculator.normalTextLevel(for: 4.49) == .fail)
    }

    @Test func largeTextThresholds() {
        #expect(ContrastCalculator.largeTextLevel(for: 4.5) == .aaa)
        #expect(ContrastCalculator.largeTextLevel(for: 3.0) == .aa)
        #expect(ContrastCalculator.largeTextLevel(for: 2.99) == .fail)
    }

    /// The five swatches from the web app's mobile palette view, with the label color the web
    /// app actually renders on each. iOS picks its band label the same way, so these must agree.
    @Test(arguments: [
        (0x2A2C32, true),  // Charade      — white label
        (0xB0ACA1, false), // Cloudy       — dark label
        (0x666770, true),  // Shuttle Gray — white label
        (0x99ABB3, false), // Gull Gray    — dark label
        (0x2D292B, true),  // Baltic Sea   — white label
    ])
    func bandLabelMatchesWebApp(hex: Int, expectsLightText: Bool) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        #expect(
            ContrastCalculator.prefersLightText(onRed: red, green: green, blue: blue)
                == expectsLightText
        )
    }

    @Test func pureExtremesPickOpposingLabels() {
        #expect(ContrastCalculator.prefersLightText(onRed: 0, green: 0, blue: 0))
        #expect(!ContrastCalculator.prefersLightText(onRed: 1, green: 1, blue: 1))
    }
}

/// Pins the port of `suggestFix()` from the web's `lib/wcagContrast.ts` — the algorithm behind the
/// Contrast tool's "Fix it" and the health report's auto-remap.
///
/// Expected values come from transcribing that TypeScript independently, so a mistranslation
/// fails here rather than shipping a nudge that lands somewhere different from the web's.
@Suite("Contrast auto-fix")
struct ContrastFixTests {
    private func swatch(_ hex: String) -> PaletteColor {
        PaletteColor(hexString: hex, dominance: 0.2)!
    }

    /// Against a dark anchor it should go *lighter* — away from the anchor's luminance.
    @Test func nudgesAwayFromADarkAnchor() {
        let fix = ContrastCalculator.suggestFix(
            adjust: swatch("#FF6B6B"), anchor: swatch("#2A2C32"), target: 4.5
        )

        #expect(fix?.swatch.hex == "#FF7070")
        #expect(fix?.wentLighter == true)
        #expect((fix?.ratio ?? 0) >= 4.5)
    }

    /// Against a light anchor it should go darker instead — the same colour, the other direction.
    @Test func nudgesAwayFromALightAnchor() {
        let fix = ContrastCalculator.suggestFix(
            adjust: swatch("#FF6B6B"), anchor: swatch("#FFFFFF"), target: 4.5
        )

        #expect(fix?.swatch.hex == "#EA0000")
        #expect(fix?.wentLighter == false)
        #expect((fix?.ratio ?? 0) >= 4.5)
    }

    @Test func reachesAAAWhenAsked() {
        let fix = ContrastCalculator.suggestFix(
            adjust: swatch("#4ECDC4"), anchor: swatch("#FFFFFF"), target: 7
        )

        #expect(fix?.swatch.hex == "#1C615C")
        #expect((fix?.ratio ?? 0) >= 7)
    }

    /// Hue and saturation are held; only lightness moves. A fix that changed the hue would not be
    /// the same brand colour any more, which is the whole point of nudging rather than replacing.
    @Test func keepsTheHue() {
        let original = swatch("#4ECDC4")
        let fix = ContrastCalculator.suggestFix(adjust: original, anchor: swatch("#FFFFFF"), target: 7)
        let before = ColorMath.hsl(fromRed: original.red, green: original.green, blue: original.blue)
        let after = ColorMath.hsl(
            fromRed: fix!.swatch.red, green: fix!.swatch.green, blue: fix!.swatch.blue
        )

        #expect(abs(before.hue - after.hue) < 2)
    }

    /// Nil is a real answer, not a failure: no lightness of this hue clears 21:1 against itself.
    @Test func returnsNothingWhenNoLightnessCanReachTheTarget() {
        let fix = ContrastCalculator.suggestFix(
            adjust: swatch("#808080"), anchor: swatch("#808080"), target: 21
        )
        #expect(fix == nil)
    }
}
