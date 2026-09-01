import SwiftUI
import PhotosUI
import Observation

@MainActor
@Observable
final class ExtractorViewModel {
    var selectedItem: PhotosPickerItem? {
        didSet { Task { await loadAndExtract() } }
    }
    var sourceImage: UIImage?
    var palette: ExtractedPalette?
    var isExtracting = false

    private func loadAndExtract() async {
        guard let selectedItem else { return }
        isExtracting = true
        defer { isExtracting = false }

        guard
            let data = try? await selectedItem.loadTransferable(type: Data.self),
            let image = UIImage(data: data)
        else { return }

        sourceImage = image
        palette = await Task.detached(priority: .userInitiated) {
            ColorExtractionService.extractPalette(from: image)
        }.value
    }
}
