import SwiftUI

/// Export options, presented from the dock's share button.
///
/// This was a plain `Menu`, which meant it rendered in iOS's default menu chrome — the one piece
/// of the app that didn't match anything else. It now mirrors `ToolsSheet` so both dock sheets
/// look like the same product.
///
/// Card summaries carry the destination, because "Save" and "Share" go to genuinely different
/// places: the account (which syncs to the web Library) versus the device.
struct ShareSheet: View {
    let palette: ExtractedPalette
    let shareable: SharablePaletteImage?
    let onSaveToAccount: () -> Void
    let onCopied: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    Button {
                        dismiss()
                        onSaveToAccount()
                    } label: {
                        card(
                            "bookmark",
                            "Save to account",
                            "Named, and synced to your web Library"
                        )
                    }
                    .buttonStyle(.plain)

                    if let shareable {
                        ShareLink(
                            item: shareable,
                            preview: SharePreview("ColorSense palette", image: shareable.preview)
                        ) {
                            card(
                                "square.and.arrow.up",
                                "Share as image",
                                "PNG to Photos, AirDrop or Messages"
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        UIPasteboard.general.string = PaletteExportService.hexList(palette)
                        dismiss()
                        onCopied("Hex codes copied")
                    } label: {
                        card("number", "Copy hex codes", "One per line")
                    }
                    .buttonStyle(.plain)

                    Button {
                        UIPasteboard.general.string = PaletteExportService.cssVariables(palette)
                        dismiss()
                        onCopied("CSS variables copied")
                    } label: {
                        card("curlybraces", "Copy CSS", "Custom properties for :root")
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
            }
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .safeAreaInset(edge: .top) {
                Text("\(palette.colors.count) colors in this palette")
                    .font(BrandFont.ui(13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func card(_ systemImage: String, _ title: String, _ summary: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 20))
                .foregroundStyle(BrandColor.coral)
            Text(title)
                .font(BrandFont.ui(16, weight: .medium))
            Text(summary)
                .font(BrandFont.ui(13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .foregroundStyle(.primary)
    }
}
