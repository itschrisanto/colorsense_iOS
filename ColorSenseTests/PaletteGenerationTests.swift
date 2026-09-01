import Testing
import Foundation
@testable import ColorSense

struct PaletteGeneratorTests {
    @Test func generatesTheRequestedNumberOfColors() {
        let colors = PaletteGenerator.colors(
            anchoredTo: ExtractedPalette.sample.colors, count: 5, iteration: 0
        )
        #expect(colors.count == 5)
    }

    /// Iteration 0 is the monochromatic scheme — every hue offset is 0 — so output hues should
    /// stay close to their anchors. This is what "tight" means in the web's relatedPalette.
    @Test func earlyIterationsStayNearTheAnchorHues() {
        let anchors = [PaletteColor(hex: 0x3366CC, dominance: 0.5)]
        let anchorHue = ColorMath.hsl(
            fromRed: anchors[0].red, green: anchors[0].green, blue: anchors[0].blue
        ).hue

        for _ in 0..<20 {
            let generated = PaletteGenerator.colors(anchoredTo: anchors, count: 1, iteration: 0)
            let hue = ColorMath.hsl(
                fromRed: generated[0].red, green: generated[0].green, blue: generated[0].blue
            ).hue
            // Monochromatic jitter is ±7°; allow a little slack for the 8-bit round trip.
            #expect(circularHueDistance(hue, anchorHue) <= 12)
        }
    }

    @Test func generatingNeverProducesAnEmptyOrOversizedPalette() {
        for iteration in 0..<25 {
            let colors = PaletteGenerator.colors(
                anchoredTo: ExtractedPalette.sample.colors, count: 5, iteration: iteration
            )
            #expect(colors.count == 5)
        }
    }

    /// Saturation and lightness are clamped, so no iteration — tight or wide — can bleach the
    /// palette to white or sink it to black.
    @Test func everyIterationStaysWithinUsableBrightness() {
        for iteration in 0..<30 {
            let colors = PaletteGenerator.colors(
                anchoredTo: ExtractedPalette.sample.colors, count: 5, iteration: iteration
            )
            for swatch in colors {
                let hsl = ColorMath.hsl(
                    fromRed: swatch.red, green: swatch.green, blue: swatch.blue
                )
                #expect(hsl.lightness >= 0.17 && hsl.lightness <= 0.91)
            }
        }
    }

    @Test func emptyAnchorsFallBackToAMidGreyRatherThanCrashing() {
        let colors = PaletteGenerator.colors(anchoredTo: [], count: 5, iteration: 0)
        #expect(colors.count == 5)
    }

    private func circularHueDistance(_ a: Double, _ b: Double) -> Double {
        let raw = abs(a - b).truncatingRemainder(dividingBy: 360)
        return min(raw, 360 - raw)
    }
}

@MainActor
struct PaletteStoreTests {
    /// Each test gets its own file so persistence is exercised for real without tests colliding.
    private func temporaryStore() -> (PaletteStore, URL) {
        let url = URL.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json")
        return (PaletteStore(fileURL: url), url)
    }

    @Test func firstLaunchShowsTheBrandDefault() {
        let (store, _) = temporaryStore()
        #expect(store.isShowingDefault)
        #expect(store.palette.colors.map(\.hex) == ExtractedPalette.brandDefault.colors.map(\.hex))
    }

    @Test func aStoredPaletteIsRestoredOnRelaunch() {
        let (store, url) = temporaryStore()
        store.replace(with: .sample)

        let relaunched = PaletteStore(fileURL: url)
        #expect(!relaunched.isShowingDefault)
        #expect(relaunched.palette.colors.map(\.hex) == ExtractedPalette.sample.colors.map(\.hex))
    }

    @Test func generationCountSurvivesRelaunch() {
        let (store, url) = temporaryStore()
        store.replace(with: .sample)
        store.generate()
        store.generate()

        #expect(PaletteStore(fileURL: url).palette.generation == 2)
    }

    @Test func extractingResetsTheGenerationRunAndReanchors() {
        let (store, _) = temporaryStore()
        store.replace(with: .sample)
        store.generate()
        #expect(store.palette.generation == 1)

        store.replace(with: .brandDefault)
        #expect(store.palette.generation == 0)
        #expect(store.palette.anchors.map(\.hex) == ExtractedPalette.brandDefault.colors.map(\.hex))
    }

    @Test func generatingLeavesLockedSwatchesUntouched() {
        let (store, _) = temporaryStore()
        store.replace(with: .sample)
        let lockedID = store.palette.colors[1].id
        store.toggleLock(for: lockedID)
        let lockedHex = store.palette.colors[1].hex

        for _ in 0..<5 { store.generate() }

        #expect(store.palette.colors[1].hex == lockedHex)
        #expect(store.palette.colors[1].isLocked)
    }

    @Test func generatingChangesUnlockedSwatches() {
        let (store, _) = temporaryStore()
        store.replace(with: .sample)
        let before = store.palette.colors.map(\.hex)
        store.generate()
        #expect(store.palette.colors.map(\.hex) != before)
    }

    @Test func lockStateSurvivesRelaunch() {
        let (store, url) = temporaryStore()
        store.replace(with: .sample)
        store.toggleLock(for: store.palette.colors[0].id)

        #expect(PaletteStore(fileURL: url).palette.colors[0].isLocked)
    }

    @Test func togglingLockTwiceReturnsToUnlocked() {
        let (store, _) = temporaryStore()
        store.replace(with: .sample)
        let id = store.palette.colors[0].id
        store.toggleLock(for: id)
        store.toggleLock(for: id)
        #expect(!store.palette.colors[0].isLocked)
    }

    @Test func insertingAtASeamPersistsTheColorAndItsCustomName() {
        let (store, url) = temporaryStore()
        store.replace(with: .sample)
        let savedColor = PaletteColor(hex: 0x123456, dominance: 0, customName: "Deep Harbor")

        #expect(store.insert(savedColor, at: 2))
        #expect(store.palette.colors[2].hex == "#123456")
        #expect(store.palette.colors[2].name == "Deep Harbor")
        #expect(store.palette.anchors[2].hex == "#123456")

        let relaunched = PaletteStore(fileURL: url)
        #expect(relaunched.palette.colors[2].name == "Deep Harbor")
    }

    @Test func paletteCannotGrowPastEightColors() {
        let (store, _) = temporaryStore()
        store.replace(with: .sample)

        while store.palette.colors.count < PaletteStore.maximumColorCount {
            #expect(store.insert(PaletteColor(hex: 0xABCDEF, dominance: 0), at: 1))
        }

        #expect(store.palette.colors.count == 8)
        #expect(!store.insert(PaletteColor(hex: 0x111111, dominance: 0), at: 1))
        #expect(store.palette.colors.count == 8)
    }

    @Test func oversizedImportedPaletteIsClampedToTheWorkspaceLimit() {
        let (store, _) = temporaryStore()
        let colors = (0..<10).map { index in
            PaletteColor(hex: UInt32(index * 0x111111), dominance: 0.1)
        }

        store.replace(with: ExtractedPalette(colors: colors, createdAt: Date()))

        #expect(store.palette.colors.count == PaletteStore.maximumColorCount)
        #expect(store.palette.anchors.count == PaletteStore.maximumColorCount)
    }

    @Test func removingAndRestoringAColorKeepsItsPosition() {
        let (store, _) = temporaryStore()
        store.replace(with: .sample)
        let target = store.palette.colors[2]

        let removal = store.remove(swatchID: target.id)
        #expect(removal?.index == 2)
        #expect(store.palette.colors.count == 4)
        #expect(store.palette.anchors.count == 4)

        if let removal { store.restore(removal) }
        #expect(store.palette.colors[2].hex == target.hex)
        #expect(store.palette.colors.count == 5)
    }

    @Test func finalColorCannotBeRemoved() {
        let (store, _) = temporaryStore()
        store.replace(
            with: ExtractedPalette(
                colors: [PaletteColor(hex: 0xFF6B6B, dominance: 1)],
                createdAt: Date()
            )
        )

        #expect(store.remove(swatchID: store.palette.colors[0].id) == nil)
        #expect(store.palette.colors.count == PaletteStore.minimumColorCount)
    }
}

struct SavedColorTests {
    @Test func oneSwatchSavedPaletteBecomesAReusableNamedColor() {
        let saved = SavedPaletteService.SavedPalette(
            id: 42,
            name: "Product Coral",
            colors: ["#FF6B6B"],
            createdAt: "2026-09-02"
        )

        #expect(saved.savedColor?.name == "Product Coral")
        #expect(saved.savedColor?.swatch.name == "Product Coral")
        #expect(saved.savedColor?.swatch.hex == "#FF6B6B")
    }

    @Test func multiSwatchSavedPaletteDoesNotMasqueradeAsAColor() {
        let saved = SavedPaletteService.SavedPalette(
            id: 43,
            name: "Brand palette",
            colors: ["#FF6B6B", "#4ECDC4"],
            createdAt: "2026-09-02"
        )

        #expect(saved.savedColor == nil)
    }
}

struct PaletteColorHexParsingTests {
    @Test func acceptsCommonSixDigitHexFormats() {
        #expect(PaletteColor(hexString: "#FF6B6B", dominance: 0)?.hex == "#FF6B6B")
        #expect(PaletteColor(hexString: "4ecdc4", dominance: 0)?.hex == "#4ECDC4")
        #expect(PaletteColor(hexString: "  0xFFD93D  ", dominance: 0)?.hex == "#FFD93D")
    }

    @Test func rejectsIncompleteOrMalformedHexValues() {
        #expect(PaletteColor(hexString: "#FFF", dominance: 0) == nil)
        #expect(PaletteColor(hexString: "#GGGGGG", dominance: 0) == nil)
        #expect(PaletteColor(hexString: "#12345678", dominance: 0) == nil)
    }
}
