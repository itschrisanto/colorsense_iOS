import SwiftUI

/// Bridges a picked photo to a palette. Stateless on purpose — the Extractor is no longer a
/// screen that owns a palette, it is an action that replaces the app's one shared palette
/// (see `PaletteStore`).
enum PhotoExtractor {
    /// Clusters an already-decoded image into a palette. Non-optional by design: `PhotoSourcePicker`
    /// owns loading from the camera or the library and reports its own read failures, so by the
    /// time an image reaches here there is nothing left to fail.
    static func palette(from image: UIImage) async -> ExtractedPalette {
        await Task.detached(priority: .userInitiated) {
            ColorExtractionService.extractPalette(from: image)
        }.value
    }
}
