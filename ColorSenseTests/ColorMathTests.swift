import Testing
@testable import ColorSense

/// Pins the ported color math to values read directly off the web app's own detail card for
/// #666770 (Shuttle Gray). If any of these drift, iOS and colorsense.online have stopped
/// agreeing about the same hex — which is the whole reason this math was ported rather than
/// reimplemented.
struct ColorMathTests {
    private let shuttleGray = PaletteColor(hex: 0x666770, dominance: 0.18)

    @Test func conversionsMatchTheWebDetailCard() {
        let byLabel = Dictionary(
            uniqueKeysWithValues: shuttleGray.conversions.map { ($0.label, $0.value) }
        )
        #expect(byLabel["HEX"] == "666770")
        #expect(byLabel["RGB"] == "102, 103, 112")
        #expect(byLabel["HSL"] == "234, 5, 42")
        #expect(byLabel["CMYK"] == "9, 8, 0, 56")
        #expect(byLabel["LAB"] == "44, 2, -5")
        #expect(byLabel["LCH"] == "44, 5, 292")
    }

    @Test func conversionsAppearInTheWebsOrder() {
        #expect(shuttleGray.conversions.map(\.label) == ["HEX", "RGB", "HSL", "CMYK", "LAB", "LCH"])
    }

    @Test func accessibilityRowsMatchTheWebDetailCard() {
        let rows = shuttleGray.accessibilityRows
        #expect(rows.map(\.label) == ["On white", "On black"])
        #expect(String(format: "%.2f", rows[0].ratio) == "5.62")
        #expect(rows[0].rating.label == "GOOD 4/5")
        #expect(String(format: "%.2f", rows[1].ratio) == "3.74")
        #expect(rows[1].rating.label == "OK 3/5")
    }

    @Test func ratingBoundariesMatchTheWebScale() {
        #expect(ContrastCalculator.rating(for: 21.0).label == "GREAT 5/5")
        #expect(ContrastCalculator.rating(for: 7.0).label == "GREAT 5/5")
        #expect(ContrastCalculator.rating(for: 6.99).label == "GOOD 4/5")
        #expect(ContrastCalculator.rating(for: 4.5).label == "GOOD 4/5")
        #expect(ContrastCalculator.rating(for: 4.49).label == "OK 3/5")
        #expect(ContrastCalculator.rating(for: 3.0).label == "OK 3/5")
        #expect(ContrastCalculator.rating(for: 2.99).label == "POOR 2/5")
        #expect(ContrastCalculator.rating(for: 2.0).label == "POOR 2/5")
        #expect(ContrastCalculator.rating(for: 1.99).label == "POOR 1/5")
    }

    @Test func shuttleGrayReadsAsAMidNeutral() {
        // Saturation 5% puts it under the web's 0.12 neutral cutoff, and lightness 42% puts it
        // between the light (>=0.8) and dark (<=0.25) bands — so: NEUTRAL_MID.
        let insight = ColorInsights.insight(for: shuttleGray)
        #expect(insight.psychology.hasPrefix("Mid greys feel neutral"))
        #expect(insight.meaning.hasPrefix("Signals balance"))
        #expect(insight.applications.hasPrefix("Useful for borders"))
    }

    @Test func hueFamiliesPickTheExpectedInsight() {
        let cases: [(UInt32, String)] = [
            (0xFF0000, "Reds are energising"),          // hue 0
            (0xFF8000, "Warm oranges radiate"),         // hue ~30
            (0xFFE100, "Yellows feel cheerful"),        // hue ~53
            (0x22AA44, "Greens feel calm"),             // hue ~133
            (0x22CCCC, "Teals and cyans feel fresh"),   // hue 180
            (0x2255DD, "Blues read as stable"),         // hue ~222
            (0x8844DD, "Purples feel imaginative"),     // hue ~270
            (0xDD44AA, "Pinks and magentas feel warm"), // hue ~320
        ]
        for (hex, expectedPrefix) in cases {
            let insight = ColorInsights.insight(for: PaletteColor(hex: hex, dominance: 0))
            #expect(
                insight.psychology.hasPrefix(expectedPrefix),
                "\(String(format: "#%06X", hex)) got: \(insight.psychology)"
            )
        }
    }

    @Test func harmoniesUseTheWebsTitlesAndCounts() {
        let harmonies = ColorHarmony.all(for: shuttleGray)
        #expect(harmonies.map(\.title) == [
            "Analogous", "Complementary", "Split Complementary", "Triadic",
        ])
        #expect(harmonies.map(\.colors.count) == [3, 2, 3, 3])
    }

    /// Near-greys have no hue to rotate, so the web substitutes a visible mid-tone. Without that
    /// guard every harmony chip off Shuttle Gray would come back grey.
    @Test func harmoniesOffANearGreyAreNotAllGrey() {
        let analogous = ColorHarmony.all(for: shuttleGray)[0]
        let saturations = analogous.colors.map {
            ColorMath.hsl(fromRed: $0.red, green: $0.green, blue: $0.blue).saturation
        }
        #expect(saturations.contains { $0 > 0.3 })
    }

    @Test func hslRoundTripsThroughRgb() {
        for hex: UInt32 in [0x666770, 0xFF6B6B, 0x4ECDC4, 0xFFD93D, 0x7C6DEB, 0x000000, 0xFFFFFF] {
            let swatch = PaletteColor(hex: hex, dominance: 0)
            let hsl = ColorMath.hsl(fromRed: swatch.red, green: swatch.green, blue: swatch.blue)
            let rgb = ColorMath.rgb(from: hsl)
            let roundTripped = PaletteColor(
                red: rgb.red, green: rgb.green, blue: rgb.blue, dominance: 0
            )
            #expect(roundTripped.hex == swatch.hex)
        }
    }
}
