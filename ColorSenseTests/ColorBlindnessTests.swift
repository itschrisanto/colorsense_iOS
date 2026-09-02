import Testing
import Foundation
@testable import ColorSense

/// Pins the port of `lib/colorBlind.ts` — the Machado (2009) simulation and the ΔE-based
/// confusable-pair check.
///
/// Expected values come from transcribing that TypeScript independently and running it over the
/// same colours, not from this implementation, so the test can actually catch a mistranslation
/// rather than confirming the Swift agrees with itself.
@Suite("Colour blindness")
struct ColorBlindnessTests {
    private func swatch(_ hex: String) -> PaletteColor {
        PaletteColor(hexString: hex, dominance: 0.2)!
    }

    private func palette(_ hexes: [String]) -> [PaletteColor] {
        hexes.map(swatch)
    }

    private let brand = ["#FF6B6B", "#4ECDC4", "#FFD93D", "#7C6DEB", "#2A2C32"]

    /// The matrices are defined in *linear* sRGB. Applying them to gamma-encoded channels gives
    /// plausible-looking but wrong colours, which is exactly the kind of error that survives a
    /// glance — hence exact hexes rather than approximate ones.
    @Test func deuteranopiaMatchesTheWeb() {
        let simulated = ColorBlindness.simulate(palette(brand), as: .deuteranopia).map(\.hex)
        #expect(simulated == ["#B5A767", "#AFB4C5", "#FAE047", "#227BE8", "#2A2C32"])
    }

    @Test func protanopiaMatchesTheWeb() {
        let simulated = ColorBlindness.simulate(palette(brand), as: .protanopia).map(\.hex)
        #expect(simulated == ["#90886A", "#C2C3C4", "#F0D51C", "#2883EF", "#2A2C32"])
    }

    @Test func tritanopiaMatchesTheWeb() {
        let simulated = ColorBlindness.simulate(palette(brand), as: .tritanopia).map(\.hex)
        #expect(simulated == ["#FF506C", "#00D2CA", "#FFC7BB", "#5689A2", "#282D2E"])
    }

    /// A well-separated palette should raise nothing. A check that only ever fires is as useless
    /// as one that never does.
    @Test func aWellSeparatedPaletteHasNoConfusablePairs() {
        for kind in ColorBlindness.Kind.allCases {
            #expect(ColorBlindness.confusablePairs(palette(brand), as: kind).isEmpty)
        }
    }

    /// A red and an olive that both collapse toward the same yellow-brown under deuteranopia —
    /// the classic failure where colour alone is carrying meaning.
    @Test func aRedAndAnOliveCollapseTogether() {
        let pairs = ColorBlindness.confusablePairs(
            palette(["#C0392B", "#7D6608", "#2A2C32"]),
            as: .deuteranopia
        )

        #expect(pairs.count == 1)
        #expect(pairs.first?.first == 0)
        #expect(pairs.first?.second == 1)
        // 5.20 by the independent transcription.
        #expect((pairs.first?.deltaE ?? 0) > 5.1)
        #expect((pairs.first?.deltaE ?? 0) < 5.3)
    }

    @Test func pairsComeBackClosestFirst() {
        let pairs = ColorBlindness.confusablePairs(
            palette(["#C0392B", "#7D6608", "#A93226"]),
            as: .deuteranopia
        )

        #expect(pairs.count > 1)
        #expect(pairs == pairs.sorted { $0.deltaE < $1.deltaE })
    }
}
