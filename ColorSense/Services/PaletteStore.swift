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
            palette = stored
            isShowingDefault = false
        } else {
            palette = .brandDefault
            isShowingDefault = true
        }
    }

    /// Replaces the palette with a freshly extracted one, resetting the generation run.
    func replace(with palette: ExtractedPalette) {
        self.palette = palette
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
            current.isLocked ? current : replacement
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
