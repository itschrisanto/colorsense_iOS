import SwiftUI
import Photos

/// Builds the shareable representations of a palette offered by the Extractor's Export menu.
/// Everything here is generated on-device — exporting never touches the network.
enum PaletteExportService {
    static func hexList(_ palette: ExtractedPalette) -> String {
        palette.colors.map(\.hex).joined(separator: "\n")
    }

    static func cssVariables(_ palette: ExtractedPalette) -> String {
        let lines = palette.colors.enumerated().map { index, swatch in
            "  --color-\(index + 1): \(swatch.hex); /* \(swatch.name) */"
        }
        return ":root\n{\n" + lines.joined(separator: "\n") + "\n}"
    }

    /// Renders the palette as a shareable card. Returns nil if the renderer produces nothing,
    /// which SwiftUI allows for an empty palette.
    @MainActor
    static func uiImage(for palette: ExtractedPalette) -> UIImage? {
        let renderer = ImageRenderer(content: ExportCard(palette: palette))
        renderer.scale = 3
        return renderer.uiImage
    }

    @MainActor
    static func image(for palette: ExtractedPalette) -> Image? {
        uiImage(for: palette).map(Image.init(uiImage:))
    }

    /// Writes the rendered palette into the user's photo library. Requests add-only access —
    /// the app never needs to read the library, only contribute to it.
    @MainActor
    static func saveToPhotos(_ palette: ExtractedPalette) async -> Result<Void, SaveError> {
        guard let data = uiImage(for: palette)?.pngData() else { return .failure(.renderFailed) }

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return .failure(.notPermitted) }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
            }
            return .success(())
        } catch {
            return .failure(.writeFailed)
        }
    }

    enum SaveError: Error {
        case renderFailed
        case notPermitted
        case writeFailed

        var message: String {
            switch self {
            case .renderFailed: return "Couldn't render the palette."
            case .notPermitted: return "Allow photo access in Settings to save palettes."
            case .writeFailed: return "Couldn't save the palette."
            }
        }
    }

    /// The band stack as it appears when exported. Kept separate from `ExtractorView` so the
    /// shared image has fixed dimensions instead of inheriting whatever the screen happens to be.
    private struct ExportCard: View {
        let palette: ExtractedPalette

        var body: some View {
            VStack(spacing: 0) {
                ForEach(palette.colors) { swatch in
                    HStack(alignment: .firstTextBaseline) {
                        Text(swatch.hex)
                            .font(BrandFont.mono(26))
                        Spacer()
                        Text(swatch.name)
                            .font(BrandFont.ui(18))
                            .opacity(0.8)
                    }
                    .foregroundStyle(swatch.legibleForeground)
                    .padding(.horizontal, 28)
                    .frame(width: 900, height: 150, alignment: .leading)
                    .background(swatch.color)
                }
            }
        }
    }
}
