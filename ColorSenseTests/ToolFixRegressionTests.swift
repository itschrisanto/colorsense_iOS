import Foundation
import SwiftUI
import Testing
@testable import ColorSense

@MainActor
@Suite("Tool apply regressions")
struct ToolFixRegressionTests {
    private func proposal(original: PaletteColor, against: PaletteColor, target: Double = 7) throws -> ContrastFixSheet.Proposal {
        let fix = try #require(ContrastCalculator.suggestFix(adjust: original, anchor: against, target: target))
        return .init(id: 0, swatchID: original.id, sourceHex: original.hex, problem: "Test pairing",
                     original: original, proposed: fix.swatch, against: against, changingIsForeground: true,
                     currentRatio: ContrastCalculator.ratio(r1: original.red, g1: original.green, b1: original.blue,
                                                           r2: against.red, g2: against.green, b2: against.blue),
                     newRatio: fix.ratio, wentLighter: fix.wentLighter)
    }

    @Test func contrastApplyUpdatesPaletteAndPersistsWithoutEmptyingSession() throws {
        let file = URL.temporaryDirectory.appendingPathComponent("fix-test-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: file) }
        let store = PaletteStore(fileURL: file)
        store.replace(with: .init(colors: [PaletteColor(hex: 0xffffff, dominance: 0.6),
                                         PaletteColor(hex: 0x888888, dominance: 0.4)], createdAt: Date()))
        let vm = WCAGCheckerViewModel(palette: store.palette)
        let source = store.palette.colors[1]
        let fix = try proposal(original: source, against: store.palette.colors[0])
        let session = ContrastFixSheet.Session(proposals: [fix])

        #expect(vm.apply(fix, to: store))
        #expect(store.palette.colors[1].hex == fix.proposed.hex)
        #expect(store.palette.colors[1].id == source.id)
        #expect(store.palette.anchors[1].hex == fix.proposed.hex)
        #expect(vm.ratio >= 7)
        #expect(session.proposals.count == 1)
        #expect(session.proposals[0].original.hex == "#888888")
        #expect(PaletteStore(fileURL: file).palette.colors[1].hex == fix.proposed.hex)
    }

    @Test func healthApplyTracksIdentityAfterReorderingAndRejectsStaleChanges() throws {
        let file = URL.temporaryDirectory.appendingPathComponent("health-test-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: file) }
        let store = PaletteStore(fileURL: file)
        let source = store.palette.colors[0]
        let changed = PaletteColor(hex: 0x123456, dominance: source.dominance)
        store.move(from: 0, to: 2)
        #expect(store.applyFix(changed, to: source.id, expectedHex: source.hex))
        #expect(store.palette.colors.first { $0.id == source.id }?.hex == changed.hex)
        #expect(!store.applyFix(source, to: source.id, expectedHex: source.hex))
        #expect(!store.applyFix(source, to: UUID(), expectedHex: source.hex))
    }

    @Test func checkerSyncsSharedChangesAndTracksAssignedIdentity() {
        var palette = ExtractedPalette.sample
        let vm = WCAGCheckerViewModel(palette: palette)
        vm.assign(palette.colors[2], to: .text)
        vm.assign(palette.colors[1], to: .background)
        vm.swap()
        #expect(vm.foregroundID == palette.colors[1].id)
        #expect(vm.backgroundID == palette.colors[2].id)
        var replacement = PaletteColor(hex: 0xffffff, dominance: 0.2)
        replacement.id = palette.colors[1].id
        palette.colors[1] = replacement
        vm.synchronize(with: palette)
        #expect(vm.foregroundSwatch.hex == "#FFFFFF")
        #expect(vm.paletteColors[1].hex == "#FFFFFF")
    }

    @Test func loadingAnotherPaletteReseedsTheChecker() {
        let vm = WCAGCheckerViewModel(palette: .sample)
        let newPalette = ExtractedPalette.brandDefault
        vm.synchronize(with: newPalette)
        #expect(vm.backgroundID == newPalette.colors[0].id)
        #expect(vm.backgroundSwatch.hex == newPalette.colors[0].hex)
    }

    @Test func aCustomPickerEditDetachesFromThePaletteSwatchThatSeededIt() {
        let vm = WCAGCheckerViewModel(palette: .sample)
        #expect(vm.foregroundID != nil)
        vm.assignCustom(.red, to: .text)
        #expect(vm.foregroundID == nil)
        #expect(vm.foregroundSwatch.hex == PaletteColor(color: .red).hex)
    }

    @Test func staleContrastPreviewCannotOverwriteANewerSwatch() throws {
        let file = URL.temporaryDirectory.appendingPathComponent("stale-fix-test-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: file) }
        let store = PaletteStore(fileURL: file)
        let vm = WCAGCheckerViewModel(palette: store.palette)
        vm.assign(store.palette.colors[0], to: .text)
        let fix = try proposal(original: store.palette.colors[0], against: PaletteColor(hex: 0xffffff, dominance: 0))
        store.replace(at: 0, with: PaletteColor(hex: 0x123456, dominance: 0.3))
        vm.synchronize(with: store.palette)
        #expect(!vm.apply(fix, to: store))
        #expect(store.palette.colors[0].hex == "#123456")
    }
}

@Suite("SVG shuffle regressions")
struct SvgShuffleRegressionTests {
    @Test func swapsAndCyclesDoNotCascade() {
        let svg = ##"<svg><rect fill="#f00"/><rect fill="#00f"/><style>.a{fill:#f00}.b{stroke:#00f}</style></svg>"##
        let result = SvgRecolor.recolor(svg, mapping: ["#ff0000": "#0000ff", "#0000ff": "#ff0000"])
        #expect(result.contains(##"<rect fill="#0000ff"/><rect fill="#ff0000"/>"##))
        #expect(result.contains(".a{fill:#0000ff}.b{stroke:#ff0000}"))
        let cycle = SvgRecolor.recolor(##"<svg><a fill="#111111"/><b fill="#222222"/><c fill="#333333"/></svg>"##,
                                      mapping: ["#111111": "#222222", "#222222": "#333333", "#333333": "#111111"])
        #expect(cycle.contains(##"<a fill="#222222"/><b fill="#333333"/><c fill="#111111"/>"##))
    }

    @Test func shufflePreservesTheMultisetAndAlwaysChangesAMovableArrangement() {
        let found = ["#111111", "#222222", "#333333"]
        let mapping = ["#111111": "#ff0000", "#222222": "#0000ff", "#333333": "#ff0000"]
        for _ in 0..<100 {
            let result = SvgRecolor.shuffledMapping(found: found, mapping: mapping)
            #expect(result != mapping)
            #expect(result.values.sorted() == mapping.values.sorted())
            #expect(Set(result.keys) == Set(found))
        }
        #expect(SvgRecolor.shuffledMapping(found: [], mapping: [:]).isEmpty)
        #expect(SvgRecolor.shuffledMapping(found: ["#111111"], mapping: [:]).isEmpty)
    }
}
