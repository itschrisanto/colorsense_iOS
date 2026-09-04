import Testing
@testable import ColorSense

/// Pins the scheme generator to the web panel's own arithmetic.
///
/// The expected values were produced by transcribing `hexToHsl`, `hslToHex` and
/// `getHarmonyColors` out of `components/lab/panels/SchemePanel.tsx` and running them, not by
/// reading them off the iOS implementation. If a port drifts, these fail.
struct ColorSchemeTests {
    private func hexes(_ base: UInt32, _ harmony: ColorScheme.Harmony) -> [String] {
        ColorScheme.colors(base: PaletteColor(hex: base, dominance: 0), harmony: harmony)
            .map(\.hex)
    }

    @Test func matchesTheWebForTheDefaultBase() {
        #expect(hexes(0x6C5CE7, .complementary) == ["#6C5CE7", "#D7E75C"])
        #expect(hexes(0x6C5CE7, .monochromatic) == ["#241694", "#3520D7", "#6C5CE7", "#9B90EF", "#D7D3F8"])
        #expect(hexes(0x6C5CE7, .analogous) == ["#5C91E7", "#6C5CE7", "#B25CE7"])
        #expect(hexes(0x6C5CE7, .splitComplementary) == ["#6C5CE7", "#E7B25C", "#91E75C"])
        #expect(hexes(0x6C5CE7, .triadic) == ["#6C5CE7", "#E76C5C", "#5CE76C"])
        #expect(hexes(0x6C5CE7, .tetradic) == ["#6C5CE7", "#E75C91", "#D7E75C", "#5CE7B2"])
    }

    @Test func matchesTheWebForBrandCoral() {
        #expect(hexes(0xFF6B6B, .complementary) == ["#FF6B6B", "#6BFFFF"])
        #expect(hexes(0xFF6B6B, .monochromatic) == ["#D10000", "#FF1F1F", "#FF6B6B", "#FF8080", "#FFCCCC"])
        #expect(hexes(0xFF6B6B, .analogous) == ["#FF6BB5", "#FF6B6B", "#FFB56B"])
        #expect(hexes(0xFF6B6B, .splitComplementary) == ["#FF6B6B", "#6BFFB5", "#6BB5FF"])
        #expect(hexes(0xFF6B6B, .triadic) == ["#FF6B6B", "#6BFF6B", "#6B6BFF"])
        #expect(hexes(0xFF6B6B, .tetradic) == ["#FF6B6B", "#B5FF6B", "#6BFFFF", "#B56BFF"])
    }

    /// Every scheme but monochromatic hands the base back untouched rather than recomputing it
    /// through HSL, which is what the web does and what keeps a chosen hex exactly as chosen.
    @Test func theBaseSurvivesUnchanged() {
        for harmony in ColorScheme.Harmony.allCases where harmony != .monochromatic {
            let colors = ColorScheme.colors(base: PaletteColor(hex: 0x123456, dominance: 0), harmony: harmony)
            #expect(colors.contains { $0.hex == "#123456" })
        }
    }

    /// This generator deliberately has no near-grey guard, unlike `ColorHarmony`. Somebody who
    /// picks grey on the wheel gets grey, rather than a hue invented for them.
    @Test func greyStaysGreyUnlikeTheOtherHarmonyPort() {
        let grey = PaletteColor(hex: 0x808080, dominance: 0)
        let scheme = ColorScheme.colors(base: grey, harmony: .triadic)
        #expect(scheme.allSatisfy { $0.red == $0.green && $0.green == $0.blue })

        // The detail screen's port answers differently for the same input, on purpose.
        let guarded = ColorHarmony.all(for: grey).first { $0.title == "Triadic" }
        #expect(guarded?.colors.contains { $0.red != $0.green } == true)
    }

    @Test func randomBasesStayInsideTheWebsRanges() {
        for _ in 0 ..< 200 {
            let hsl = { () -> ColorMath.HSL in
                let c = ColorScheme.randomBase()
                return ColorMath.hsl(fromRed: c.red, green: c.green, blue: c.blue)
            }()
            #expect(hsl.saturation >= 0.53 && hsl.saturation <= 0.92)
            #expect(hsl.lightness >= 0.38 && hsl.lightness <= 0.67)
        }
    }

    /// The wheel maps hue to an angle with 0 at the top and saturation to distance, and picking
    /// always commits at lightness 0.5. Round-tripping a point has to land back on itself.
    @Test func theWheelRoundTrips() {
        for degrees in stride(from: -180.0, to: 180.0, by: 37.0) {
            let picked = ColorScheme.color(atAngle: degrees, radius: 0.8)
            let position = ColorScheme.wheelPosition(of: picked)
            let normalise = { (a: Double) in ((a.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360) }
            #expect(abs(normalise(position.angle) - normalise(degrees)) < 1.5)
            #expect(abs(position.radius - 0.8) < 0.02)
        }
    }
}
