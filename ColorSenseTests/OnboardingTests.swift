import Testing
import Foundation
@testable import ColorSense

struct OnboardingMoodTests {
    /// Every mood has to be a usable palette the moment it lands on screen, because onboarding
    /// hands it straight to the reader as their own. Five swatches matches what the bands expect
    /// and what `brandDefault` ships.
    @Test func everyMoodIsAFiveColorPalette() {
        for mood in OnboardingMood.allCases {
            #expect(mood.colors.count == 5, "\(mood.rawValue) should have five colors")
        }
    }

    /// Dominance descends the way an extracted palette's does, so nothing downstream — the share
    /// card, the health report, the generator's anchors — has to special-case a mood palette.
    @Test func dominanceDescendsLikeAnExtractedPalette() {
        for mood in OnboardingMood.allCases {
            let dominances = mood.colors.map(\.dominance)
            #expect(dominances == dominances.sorted(by: >), "\(mood.rawValue) dominance order")
            #expect(abs(dominances.reduce(0, +) - 1.0) < 0.0001, "\(mood.rawValue) sums to 1")
        }
    }

    /// A mood is meant to read as a designed ramp rather than four arbitrary colors, and the
    /// contrast lesson later in the flow needs a genuinely dark end and a genuinely light one to
    /// have anything honest to say. Routed through `ContrastCalculator` rather than eyeballing a
    /// hex, per the project's rule that contrast decisions have exactly one source.
    @Test func eachMoodSpansDarkToLight() {
        for mood in OnboardingMood.allCases {
            let first = mood.colors.first!
            let last = mood.colors.last!
            let ratio = ContrastCalculator.ratio(
                r1: first.red, g1: first.green, b1: first.blue,
                r2: last.red, g2: last.green, b2: last.blue
            )
            #expect(ratio > 7, "\(mood.rawValue) should span a readable range, got \(ratio)")
        }
    }

    /// The analytics event carries this rawValue and nothing else. Pinning it means a rename
    /// cannot silently split a funnel that is already collecting.
    @Test func rawValuesAreStable() {
        #expect(OnboardingMood.allCases.map(\.rawValue) == ["warm", "calm", "bold", "earthy"])
        #expect(OnboardingExit.allCases.map(\.rawValue) == ["sign_up", "sign_in", "later"])
    }
}

@MainActor
struct PaletteRecolorTests {
    private func temporaryStore() -> (PaletteStore, URL) {
        let url = URL.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json")
        return (PaletteStore(fileURL: url), url)
    }

    /// The whole reason `recolor(to:)` exists rather than reusing `replace(with:)`: each band
    /// keeps its slot identity, so SwiftUI animates the color in place instead of tearing the
    /// band down and building a different one. Onboarding's live mood preview is unwatchable
    /// without this.
    @Test func recolorKeepsEachSlotsIdentity() {
        let (store, _) = temporaryStore()
        let idsBefore = store.palette.colors.map(\.id)

        store.recolor(to: OnboardingMood.warm.colors)

        #expect(store.palette.colors.map(\.id) == idsBefore)
        #expect(store.palette.colors.map(\.hex) == OnboardingMood.warm.colors.map(\.hex))
    }

    /// A mood palette is a fresh starting point, not a step in a generation run — so the run
    /// resets and the new colors become the anchors Generate will derive from.
    @Test func recolorResetsTheGenerationRun() {
        let (store, _) = temporaryStore()
        store.generate()
        store.generate()
        #expect(store.palette.generation == 2)

        store.recolor(to: OnboardingMood.calm.colors)

        #expect(store.palette.generation == 0)
        #expect(store.palette.anchors.map(\.hex) == OnboardingMood.calm.colors.map(\.hex))
        #expect(!store.isShowingDefault)
    }

    /// Onboarding restores the reader's previous palette if they back out before confirming a
    /// mood, and that palette can be a different length from the four-mood default of five.
    @Test func recolorHandlesADifferentColorCount() {
        let (store, _) = temporaryStore()
        let two = Array(OnboardingMood.bold.colors.prefix(2))

        store.recolor(to: two)

        #expect(store.palette.colors.count == 2)
        #expect(store.palette.colors.map(\.hex) == two.map(\.hex))
    }

    /// An empty array would leave the app with no palette at all and no way back, so it is
    /// refused rather than allowed to empty the screen.
    @Test func recolorIgnoresAnEmptyPalette() {
        let (store, _) = temporaryStore()
        let before = store.palette.colors.map(\.hex)

        store.recolor(to: [])

        #expect(store.palette.colors.map(\.hex) == before)
    }

    /// The mood the reader chose has to survive the app being killed — it is the artifact
    /// onboarding promised them, not a preview.
    @Test func aChosenMoodSurvivesRelaunch() {
        let (store, url) = temporaryStore()
        store.recolor(to: OnboardingMood.earthy.colors)

        let relaunched = PaletteStore(fileURL: url)

        #expect(relaunched.palette.colors.map(\.hex) == OnboardingMood.earthy.colors.map(\.hex))
        #expect(!relaunched.isShowingDefault)
    }
}
