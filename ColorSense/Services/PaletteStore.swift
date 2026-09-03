import Foundation
import Observation

/// The one palette the whole app works on. Every tool reads and writes this — the Extractor
/// replaces it, Generate drifts it, the Contrast checker seeds its pickers from it — which is
/// the model the web app states outright in its Tools sheet ("All work on the same palette").
///
/// The current palette is persisted to a JSON file so relaunching lands on whatever the user
/// last had, rather than a blank photo-picker. Only the current palette is stored; a library of
/// saved palettes is a later, separate concern.
@MainActor
@Observable
final class PaletteStore {
    static let maximumColorCount = 8
    static let minimumColorCount = 1

    struct Removal {
        let swatch: PaletteColor
        let index: Int
    }

    private(set) var palette: ExtractedPalette
    /// True when the user has only ever seen the default palette, so the UI can invite them to
    /// extract from a photo without resorting to an empty state.
    private(set) var isShowingDefault: Bool

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL

        if ProcessInfo.processInfo.arguments.contains("-sample-palette") {
            palette = .sample
            isShowingDefault = false
        } else if let stored = Self.load(from: self.fileURL) {
            palette = Self.normalized(stored)
            isShowingDefault = false
        } else {
            palette = .brandDefault
            isShowingDefault = true
        }
    }

    /// Replaces the palette with a freshly extracted one, resetting the generation run.
    func replace(with palette: ExtractedPalette) {
        self.palette = Self.normalized(palette)
        isShowingDefault = false
        persist()
    }

    /// Swaps in a whole new set of colors while keeping each slot's identity.
    ///
    /// Distinct from `replace(with:)`, which is for a genuinely new palette (an extraction) and
    /// resets the generation run. This is for showing the *same* palette wearing different
    /// colors — onboarding's live mood preview — where carrying each band's id is what lets the
    /// color animate in place instead of the band being torn down and a different one built.
    func recolor(to colors: [PaletteColor]) {
        guard !colors.isEmpty else { return }
        let existing = palette.colors
        palette.colors = colors.enumerated().map { index, replacement in
            guard index < existing.count else { return replacement }
            var carried = replacement
            carried.id = existing[index].id
            return carried
        }
        palette.anchors = palette.colors
        palette.generation = 0
        isShowingDefault = false
        persist()
    }

    /// Regenerates every unlocked swatch, anchored to the locked ones if the user has locked any
    /// and to the original extract otherwise. Mirrors `shuffle()` in the web app's LabContext.
    /// There is no cap: past `PaletteGenerator.wideningIteration` the schemes simply get bolder.
    func generate() {
        let locked = palette.lockedColors
        let anchors = locked.isEmpty ? palette.anchors : locked
        let generated = PaletteGenerator.colors(
            anchoredTo: anchors,
            count: palette.colors.count,
            iteration: palette.generation
        )

        palette.colors = zip(palette.colors, generated).map { current, replacement in
            guard !current.isLocked else { return current }
            // Same slot, new colour — not a new swatch. Carrying the id is what lets the band
            // animate from one colour to the next rather than being torn down and rebuilt.
            var recoloured = replacement
            recoloured.id = current.id
            return recoloured
        }
        palette.generation += 1
        isShowingDefault = false
        persist()
    }

    func toggleLock(for swatchID: PaletteColor.ID) {
        guard let index = palette.colors.firstIndex(where: { $0.id == swatchID }) else { return }
        palette.colors[index].isLocked.toggle()
        persist()
    }

    @discardableResult
    func insert(_ swatch: PaletteColor, at requestedIndex: Int) -> Bool {
        guard palette.colors.count < Self.maximumColorCount else { return false }
        let index = min(max(requestedIndex, 0), palette.colors.count)
        palette.colors.insert(swatch, at: index)
        palette.anchors.insert(swatch, at: min(index, palette.anchors.count))
        palette.generation = 0
        isShowingDefault = false
        persist()
        return true
    }

    /// Swaps one swatch for another in place — the auto-remap's landing point.
    ///
    /// The slot keeps its identity, so the band recolours rather than being torn down and rebuilt,
    /// exactly as Generate does. Anchors follow, or a later Generate would regenerate from the
    /// colour that was just corrected away. `generation` resets, because unlike a reorder this
    /// genuinely is a different palette to iterate from.
    func replace(at index: Int, with swatch: PaletteColor) {
        guard palette.colors.indices.contains(index) else { return }

        var recoloured = swatch
        recoloured.id = palette.colors[index].id
        recoloured.isLocked = palette.colors[index].isLocked
        palette.colors[index] = recoloured

        if palette.anchors.indices.contains(index) { palette.anchors[index] = recoloured }
        palette.generation = 0
        isShowingDefault = false
        persist()
    }

    /// Reorders a swatch within the palette.
    ///
    /// Anchors move with it. They are what Generate derives from, so leaving them in the old order
    /// would make a reordered palette regenerate into a different arrangement than the one on
    /// screen. `generation` is deliberately *not* reset, unlike insert and remove: rearranging the
    /// same colors is not a new palette to iterate from, so an in-flight run of Generate should
    /// keep its place in the scheme cycle.
    func move(from source: Int, to destination: Int) {
        let colors = palette.colors
        guard colors.indices.contains(source),
              destination >= 0, destination < colors.count,
              source != destination
        else { return }

        let swatch = palette.colors.remove(at: source)
        palette.colors.insert(swatch, at: destination)

        if palette.anchors.indices.contains(source) {
            let anchor = palette.anchors.remove(at: source)
            palette.anchors.insert(anchor, at: min(destination, palette.anchors.count))
        }

        isShowingDefault = false
        persist()
    }

    @discardableResult
    func remove(swatchID: PaletteColor.ID) -> Removal? {
        guard palette.colors.count > Self.minimumColorCount,
              let index = palette.colors.firstIndex(where: { $0.id == swatchID })
        else { return nil }

        let swatch = palette.colors.remove(at: index)
        if palette.anchors.indices.contains(index) { palette.anchors.remove(at: index) }
        palette.generation = 0
        isShowingDefault = false
        persist()
        return Removal(swatch: swatch, index: index)
    }

    func restore(_ removal: Removal) {
        _ = insert(removal.swatch, at: removal.index)
    }

    // MARK: - Persistence

    private static var defaultFileURL: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("current-palette.json")
    }

    private static func load(from url: URL) -> ExtractedPalette? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ExtractedPalette.self, from: data)
    }

    private static func normalized(_ palette: ExtractedPalette) -> ExtractedPalette {
        let colors = Array(palette.colors.prefix(maximumColorCount))
        let anchors = Array(palette.anchors.prefix(maximumColorCount))
        return ExtractedPalette(
            colors: colors,
            createdAt: palette.createdAt,
            anchors: anchors.isEmpty ? colors : anchors,
            generation: palette.generation
        )
    }

    private func persist() {
        do {
            try JSONEncoder().encode(palette).write(to: fileURL, options: .atomic)
        } catch {
            // A failed write costs the user their restored palette on next launch, which is a
            // minor degradation — not worth interrupting them over.
            print("⚠️ Could not save the current palette: \(error)")
        }
    }
}
