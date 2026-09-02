import SwiftUI
import PhotosUI

/// Bridges a picked photo to a palette. Stateless on purpose — the Extractor is no longer a
/// screen that owns a palette, it is an action that replaces the app's one shared palette
/// (see `PaletteStore`).
enum PhotoExtractor {
    /// Loads the picked item and clusters it into a palette. Returns nil if the item can't be
    /// read as an image. Clustering runs off the main actor since it walks every sampled pixel.
    static func palette(from item: PhotosPickerItem) async -> ExtractedPalette? {
        guard
            let data = try? await item.loadTransferable(type: Data.self),
            let image = UIImage(data: data)
        else { return nil }

        return await palette(from: image)
    }

    /// The same clustering, for an image that arrived already decoded — a camera capture, which
    /// hands back a `UIImage` rather than something to load. Non-optional: there is no read step
    /// left to fail, so a caller with an image always gets a palette.
    static func palette(from image: UIImage) async -> ExtractedPalette {
        await Task.detached(priority: .userInitiated) {
            ColorExtractionService.extractPalette(from: image)
        }.value
    }
}
