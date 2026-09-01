import SwiftUI
import PhotosUI

struct ExtractorView: View {
    @State private var viewModel = ExtractorViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    imagePreview
                    PhotosPicker(selection: $viewModel.selectedItem, matching: .images) {
                        Label("Choose a photo", systemImage: "photo.on.rectangle")
                            .font(BrandFont.ui(16, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(BrandColor.coral)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)

                    if viewModel.isExtracting {
                        ProgressView("Extracting colors...")
                    } else if let palette = viewModel.palette {
                        paletteGrid(palette)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Extractor")
        }
    }

    @ViewBuilder
    private var imagePreview: some View {
        if let image = viewModel.sourceImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 260)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
        } else {
            RoundedRectangle(cornerRadius: 16)
                .fill(.quaternary)
                .frame(height: 200)
                .overlay {
                    Text("No photo selected")
                        .font(BrandFont.ui(14))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
        }
    }

    private func paletteGrid(_ palette: ExtractedPalette) -> some View {
        VStack(spacing: 12) {
            ForEach(palette.colors) { swatch in
                HStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(swatch.color)
                        .frame(width: 48, height: 48)
                    VStack(alignment: .leading) {
                        Text(swatch.hex)
                            .font(BrandFont.ui(16, weight: .medium))
                        Text("\(Int((swatch.dominance * 100).rounded()))% of image")
                            .font(BrandFont.ui(13))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal)
            }
        }
    }
}

#Preview {
    ExtractorView()
}
