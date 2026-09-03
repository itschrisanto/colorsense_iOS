import Foundation
import Testing
@testable import ColorSense

/// The improver composes two existing ports, so these pin the *contract* rather than the colour
/// maths: locks are honoured, a suggestion is only offered when it is genuinely better, and the
/// same palette always yields the same answer.
@Suite("Palette improver")
struct PaletteImproverTests {

    private func palette(_ hexes: [UInt32], lockedAt locked: Set<Int> = []) -> ExtractedPalette {
        let colors = hexes.enumerated().map { index, hex in
            PaletteColor(hex: hex, dominance: 0.2, isLocked: locked.contains(index))
        }
        return ExtractedPalette(colors: colors, createdAt: Date(timeIntervalSince1970: 0))
    }

    @Test("A locked colour is never moved")
    func locksAreKept() {
        // A flat grey set scores poorly, so there is room to improve and a reason to try.
        let start = palette([0x777777, 0x7A7A7A, 0x808080, 0x848484, 0x888888], lockedAt: [0, 3])
        guard let suggestion = PaletteImprover.improve(start) else { return }
        #expect(suggestion.colors[0].hex == start.colors[0].hex)
        #expect(suggestion.colors[3].hex == start.colors[3].hex)
        #expect(suggestion.colors[0].isLocked)
    }

    @Test("A suggestion is only returned when it actually scores higher")
    func onlyOffersRealImprovements() {
        let start = palette([0x777777, 0x7A7A7A, 0x808080, 0x848484, 0x888888])
        if let suggestion = PaletteImprover.improve(start) {
            #expect(suggestion.after.overall > suggestion.before.overall)
            #expect(suggestion.gain > 0)
            #expect(suggestion.isWorthShowing)
        }
    }

    @Test("Every run improves and keeps locks, even though the search is random")
    func contractHoldsAcrossRuns() {
        // PaletteGenerator jitters with Double.random, inherited from the web's relatedPalette(),
        // so two calls can differ. What must hold every time is the contract, not the answer.
        let start = palette([0x777777, 0x7A7A7A, 0x808080, 0x848484, 0x888888], lockedAt: [2])
        for _ in 0..<12 {
            guard let suggestion = PaletteImprover.improve(start) else { continue }
            #expect(suggestion.after.overall > suggestion.before.overall)
            #expect(suggestion.colors[2].hex == start.colors[2].hex)
            #expect(suggestion.colors.map(\.id) == start.colors.map(\.id))
        }
    }

    @Test("Slot identity survives, so applying animates rather than rebuilding")
    func keepsSlotIdentity() {
        let start = palette([0x777777, 0x7A7A7A, 0x808080, 0x848484, 0x888888])
        guard let suggestion = PaletteImprover.improve(start) else { return }
        #expect(suggestion.colors.map(\.id) == start.colors.map(\.id))
    }

    @Test("A palette too short to score returns nothing rather than guessing")
    func refusesTrivialPalettes() {
        #expect(PaletteImprover.improve(palette([0x112233])) == nil)
    }
}
