import SwiftUI

/// The Visualizer: the current palette, shown in something that looks like real work.
///
/// A port of `VisualizerPanel.tsx`, with the scenes in `VisualizerScenes` and the drawing done by
/// the same sandboxed `SvgPreview` that SVG Recolor uses.
///
/// **One scene at a time, not a grid.** The web shows eleven tiles at once, which suits a desktop
/// panel and does not survive a phone: eleven live web views in a scrolling grid is both slow and
/// unreadable at that size. A picker plus one large preview shows the thing you are actually
/// looking at, and the grid's job, browsing, is what the category row does instead.
///
/// **No palette editing here.** The web panel carries its own swatches, locks and shuffle, because
/// on the web the Lab palette lives inside the panel. This app is built the other way round: the
/// palette *is* the screen behind this sheet, so editing it here would be a second place to do the
/// same thing. Close the sheet, change the palette, come back.
struct VisualizerView: View {
    let palette: ExtractedPalette
    var isPro = false

    @Environment(\.dismiss) private var dismiss

    @State private var scene: VisualizerScene = .webLanding
    @State private var category: VisualizerScene.Category?

    private var hexes: [String] { palette.colors.map { $0.hex } }

    private var scenes: [VisualizerScene] {
        guard let category else { return VisualizerScene.allCases }
        return VisualizerScene.allCases.filter { $0.category == category }
    }

    private var locked: Bool { scene.isPro && !isPro }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    preview
                    categories
                    sceneList
                }
                .padding(20)
            }
            .navigationTitle("Visualizer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                // 400x280 is the scenes' own viewBox, so the frame matches what they are drawn in
                // and nothing is letterboxed.
                Color(.secondarySystemBackground)
                SvgPreview(svg: VisualizerSVG.document(scene, palette: hexes))
                    .accessibilityHidden(true)
                if locked {
                    lockedOverlay
                }
            }
            .aspectRatio(400.0 / 280.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.12), lineWidth: 1) }
            .accessibilityElement()
            .accessibilityLabel("\(scene.title), drawn with this palette")

            HStack {
                Text(scene.title).font(BrandFont.ui(16, weight: .bold))
                Spacer()
                if !locked, let file = exportURL() {
                    ShareLink(item: file) {
                        Label("Export", systemImage: "square.and.arrow.up")
                            .font(BrandFont.ui(14, weight: .medium))
                    }
                }
            }
        }
    }

    /// Blurring the scene rather than hiding it: the point of a locked preview is that you can see
    /// what you would get. Same reasoning as `ContrastFixSheet` showing the fix it will not apply.
    private var lockedOverlay: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            VStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(BrandColor.purple)
                Text("Pro scene")
                    .font(BrandFont.ui(14, weight: .bold))
                Text("Three scenes are free. This one comes with Pro.")
                    .font(BrandFont.ui(12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
        }
    }

    private var categories: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", isOn: category == nil) { category = nil }
                ForEach(VisualizerScene.Category.allCases, id: \.self) { item in
                    chip(item.rawValue, isOn: category == item) { category = item }
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private func chip(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(BrandFont.ui(13, weight: .medium))
                .foregroundStyle(isOn ? PaletteColor(color: BrandColor.coral).legibleForeground : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isOn ? BrandColor.coral : Color(.secondarySystemBackground), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    private var sceneList: some View {
        VStack(spacing: 0) {
            ForEach(Array(scenes.enumerated()), id: \.element) { index, item in
                if index > 0 { Divider() }
                Button {
                    scene = item
                } label: {
                    HStack(spacing: 10) {
                        Text(item.title)
                            .font(BrandFont.ui(15, weight: item == scene ? .bold : .regular))
                        if item.isPro && !isPro {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(BrandColor.purple)
                        }
                        Spacer()
                        if item == scene {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(BrandColor.coral)
                        }
                    }
                    .foregroundStyle(Color.primary)
                    .padding(.vertical, 12)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(item == scene ? [.isSelected] : [])
            }
        }
    }

    /// The scene as a file the share sheet can hand on. SVG rather than PNG: it is what the scene
    /// already is, it stays sharp at any size, and it avoids rasterising a web view.
    private func exportURL() -> URL? {
        let name = scene.title.lowercased().replacingOccurrences(of: " ", with: "-")
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("colorsense-\(name).svg")
        do {
            try VisualizerSVG.document(scene, palette: hexes).write(to: file, atomically: true, encoding: .utf8)
            return file
        } catch {
            return nil
        }
    }
}
