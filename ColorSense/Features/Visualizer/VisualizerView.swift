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
/// **The palette is editable here, and it is still the same palette.** This was left out at first,
/// on the reasoning that the palette is the screen behind the sheet. That was wrong in practice:
/// the whole point of seeing a palette in a mockup is to change it and look again, and closing the
/// sheet to do that breaks the loop the tool exists for. So the strip below writes straight through
/// to `PaletteStore` rather than keeping a copy. Change a colour here and the bands behind, every
/// other tool, and the saved palette all change with it. There is no second palette.
struct VisualizerView: View {
    var isPro = false
    /// Whether this is the panel currently on screen. Its preview is a `WKWebView`, and rendering
    /// one behind an invisible panel is real work for nothing.
    var isActive = true

    @Environment(PaletteStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var scene: VisualizerScene = .webLanding
    @State private var category: VisualizerScene.Category?
    @State private var editing: EditingSwatch?
    @State private var suggestion: PaletteImprover.Suggestion?
    @State private var noSuggestion = false

    private struct EditingSwatch: Identifiable {
        let index: Int
        let swatch: PaletteColor
        var id: Int { index }
    }

    private var palette: ExtractedPalette { store.palette }
    private var hexes: [String] { palette.colors.map { $0.hex } }

    private var scenes: [VisualizerScene] {
        guard let category else { return VisualizerScene.allCases }
        return VisualizerScene.allCases.filter { $0.category == category }
    }

    private var locked: Bool { scene.isPro && !isPro }

    var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    preview
                    paletteStrip
                    categories
                    sceneList
                }
                .padding(20)
            }
            .sheet(item: $suggestion) { found in
                PaletteSuggestionSheet(
                    suggestion: found,
                    current: store.palette.colors,
                    isPro: isPro
                ) { colors in
                    withAnimation(PaletteMotion.replace(reduceMotion: reduceMotion)) {
                        store.recolor(to: colors)
                    }
                }
            }
            .alert("This palette already scores well", isPresented: $noSuggestion) {
                Button("OK") { noSuggestion = false }
            } message: {
                // Saying "nothing found" would read as a failure. Nothing was found because there
                // was nothing to find, which is worth saying as the compliment it is.
                Text("Nothing scored higher than what you have, with your locked colors kept. Lock fewer colors to give it more room.")
            }
            .sheet(item: $editing) { entry in
                VisualizerColorEditor(swatch: entry.swatch) { updated in
                    store.replace(at: entry.index, with: updated)
                }
            }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                // 400x280 is the scenes' own viewBox, so the frame matches what they are drawn in
                // and nothing is letterboxed.
                Color(.secondarySystemBackground)
                if isActive {
                    SvgPreview(svg: VisualizerSVG.document(scene, palette: hexes))
                        .accessibilityHidden(true)
                }
                if locked {
                    lockedOverlay
                }
            }
            .aspectRatio(400.0 / 280.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.12), lineWidth: 1) }
            .accessibilityElement()
            .accessibilityLabel("\(scene.title), drawn with this palette")

            Text(scene.title).font(BrandFont.ui(16, weight: .bold))

            export
        }
    }

    /// Export is Pro for **every** scene, including the free ones, which is what the web does with
    /// its PNG download. A free reader can look at three scenes and change the palette under them;
    /// taking the file away is the line.
    ///
    /// Full width and in the house style, so it reads as the same action as SVG Recolor's export
    /// rather than a link tucked beside a title. When it is locked it says why and offers no route
    /// to buy, the same as everywhere else in this app: there is no in-app purchase yet, and
    /// guideline 3.1.1 forbids pointing at an outside one.
    @ViewBuilder
    private var export: some View {
        if isPro, let file = exportURL() {
            ShareLink(item: file) {
                Label("Export this scene", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.primaryAction)
        } else {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill").font(.system(size: 13, weight: .semibold))
                Text("Exporting scenes is a Pro feature")
            }
            .font(BrandFont.ui(14, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 13))
            .accessibilityElement(children: .combine)
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

    /// The palette, editable in place.
    ///
    /// Tapping a swatch changes that colour; the lock keeps it through Shuffle. Both write to
    /// `PaletteStore`, so this is the same palette the bands behind the sheet are showing, not a
    /// working copy that would have to be committed or discarded.
    /// The palette, editable in place, with its two actions underneath.
    ///
    /// Improve and Shuffle were text buttons in the header row, which is a toolbar-sized target for
    /// a thumb and read as chrome rather than as the two things you are most likely to press. They
    /// are full-width buttons below the swatches now, which is also where the eye ends up after
    /// looking at the colours.
    ///
    /// They are deliberately two buttons. Shuffle is chance; Improve searches for a palette that
    /// actually scores higher. One control that sometimes tries harder would hide the difference.
    private var paletteStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Palette")
                .font(BrandFont.ui(13, weight: .bold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(Array(palette.colors.enumerated()), id: \.element.id) { index, swatch in
                    VStack(spacing: 0) {
                        Button {
                            editing = EditingSwatch(index: index, swatch: swatch)
                        } label: {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(swatch.color)
                                .frame(height: 52)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(swatch.name), \(swatch.hex). Change")

                        Button {
                            store.toggleLock(for: swatch.id)
                        } label: {
                            Image(systemName: swatch.isLocked ? "lock.fill" : "lock.open")
                                .font(.system(size: 13))
                                .foregroundStyle(swatch.isLocked ? BrandColor.coral : .secondary)
                                // The glyph is 13pt; the *target* is 44, the minimum a finger can
                                // reliably hit. `contentShape` is what makes that padding tappable
                                // rather than empty space around the picture.
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(swatch.isLocked
                            ? "\(swatch.hex) is locked. Unlock"
                            : "\(swatch.hex) is unlocked. Lock")
                    }
                }
            }

            HStack(spacing: 10) {
                Button {
                    if let found = PaletteImprover.improve(store.palette) {
                        suggestion = found
                    } else {
                        noSuggestion = true
                    }
                } label: {
                    Label("Improve", systemImage: "wand.and.stars")
                }
                .buttonStyle(.secondaryAction)
                .accessibilityHint("Suggests a higher scoring palette that keeps your locked colors")

                Button {
                    withAnimation(PaletteMotion.replace(reduceMotion: reduceMotion)) {
                        store.generate()
                    }
                } label: {
                    Label("Shuffle", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.secondaryAction)
                .accessibilityHint("Regenerates the unlocked colors")
            }
            .padding(.top, 2)
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
                    // 12 + a 15pt line + 12 lands at about 42, just under the 44 a finger needs.
                    // Safe as a minimum here because a ScrollView hands its children their ideal
                    // height and has no surplus to stretch this into.
                    .frame(minHeight: 44)
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
