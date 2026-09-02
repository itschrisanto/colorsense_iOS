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
    let isPro: Bool
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
                .padding(.horizontal, 16)

                proSection
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
        // Opens at medium so the free actions are reachable one-handed, but expands: the Pro
        // formats sit below the fold at that height.
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    /// The developer and designer formats. Shown to everyone rather than hidden from free users:
    /// there is no in-app purchase yet, so a free user cannot be sent anywhere to buy — but
    /// hiding them entirely would mean nobody ever learns they exist. Anyone already Pro from the
    /// web gets them immediately.
    private var proSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("DEVELOPER & DESIGN FORMATS")
                    .font(BrandFont.ui(11, weight: .bold))
                    .foregroundStyle(.secondary)
                if !isPro {
                    Text("PRO")
                        .font(BrandFont.ui(10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(BrandColor.purple.opacity(0.16))
                        .foregroundStyle(BrandColor.purple)
                        .clipShape(Capsule())
                }
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(PaletteFileFormat.allCases) { format in
                    if isPro, let url = PaletteFileExporter.file(format, for: palette) {
                        ShareLink(item: url) {
                            card(format.systemImage, format.title, format.summary)
                        }
                        .buttonStyle(.plain)
                    } else {
                        card(
                            format.systemImage,
                            format.title,
                            format.summary,
                            isLocked: !isPro
                        )
                    }
                }
            }

            if !isPro {
                // Names the tier, but deliberately points nowhere. Guideline 3.1.1 forbids
                // "buttons, external links, or other calls to action that direct customers to
                // purchasing mechanisms other than in-app purchase" — naming the web checkout
                // in prose is still a call to action. Says what Pro is, not where to buy it.
                Text("Included with ColorSense Pro.")
                    .font(BrandFont.ui(12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func card(
        _ systemImage: String,
        _ title: String,
        _ summary: String,
        isLocked: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 20))
                    .foregroundStyle(isLocked ? Color.secondary : BrandColor.coral)
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
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
        .opacity(isLocked ? 0.5 : 1)
    }
}
