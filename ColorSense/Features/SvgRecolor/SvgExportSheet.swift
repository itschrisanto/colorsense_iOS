import SwiftUI
import WebKit

/// Shared by SVG Recolor and Visualizer. Export preparation has loading, failure and retry states;
/// sharing only becomes available after the actual PNG/file exists.
struct SvgExportSheet: View {
    let document: SvgExportDocument
    @Environment(\.dismiss) private var dismiss
    @State private var renderer: SvgPNGRenderer
    @State private var image: SvgPNGImage?
    @State private var svgURL: URL?
    @State private var imageError: String?
    @State private var fileError: String?
    @State private var attempt = 0

    init(document: SvgExportDocument) {
        self.document = document
        _renderer = State(initialValue: SvgPNGRenderer(document: document))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    SvgExportCanvas(renderer: renderer)
                        .frame(width: document.size(longEdge: 280).width, height: document.size(longEdge: 280).height)
                        .accessibilityLabel("Artwork export preview")

                    if let image {
                        ShareLink(item: image, preview: SharePreview(document.name, image: image.preview)) {
                            Label("Share PNG image", systemImage: "photo")
                        }
                        .buttonStyle(.primaryAction)
                        Text("PNG image for Photos, Messages or Files. SVG keeps the artwork editable.")
                            .font(BrandFont.ui(13))
                            .foregroundStyle(.secondary)
                    } else if let imageError {
                        Text(imageError).font(BrandFont.ui(14))
                        Button("Retry image export") { attempt += 1 }
                            .buttonStyle(.secondaryAction)
                    } else {
                        ProgressView("Preparing image…")
                    }

                    if let svgURL {
                        ShareLink(item: svgURL) {
                            Label("Share SVG file", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.secondaryAction)
                    } else if let fileError {
                        Text(fileError).font(BrandFont.ui(14))
                        Button("Retry SVG export") { prepareSVG() }
                            .buttonStyle(.secondaryAction)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Export artwork")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .task(id: attempt) {
            imageError = nil
            prepareSVG()
            do {
                let data = try await renderer.pngData()
                try Task.checkCancellation()
                guard let uiImage = UIImage(data: data) else { throw SvgExportError.renderingFailed }
                image = .init(data: data, name: document.name, preview: Image(uiImage: uiImage))
            } catch is CancellationError {
                // Closing the sheet is not an export failure.
            } catch {
                imageError = error.localizedDescription
            }
        }
    }

    private func prepareSVG() {
        fileError = nil
        do { svgURL = try document.writeSVG() }
        catch { fileError = "The SVG file could not be saved. \(error.localizedDescription)" }
    }
}

private struct SvgExportCanvas: UIViewRepresentable {
    let renderer: SvgPNGRenderer
    func makeUIView(context: Context) -> WKWebView { renderer.webView }
    func updateUIView(_ view: WKWebView, context: Context) {}
}
