import SwiftUI
import PhotosUI

/// The app's home screen: whatever palette the user last had. There is no separate landing or
/// upload screen — extracting from a photo is a tool that replaces this palette, not a place you
/// go first. First launch lands on the brand palette rather than an empty state.
struct RootView: View {
    @Environment(PaletteStore.self) private var store

    @State private var toolsArePresented = false
    @State private var contrastIsPresented = false
    @State private var accountIsPresented = false
    @State private var photoPickerIsPresented = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var isExtracting = false
    @State private var detailSwatch: PaletteColor?

    var body: some View {
        NavigationStack {
            PaletteBandsView(
                palette: store.palette,
                onToggleLock: { store.toggleLock(for: $0) },
                onOpenDetail: { detailSwatch = $0 }
            )
                .overlay { if isExtracting { extractingOverlay } }
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                // The bands stop below the bar rather than running under it, so there is nothing
                // for a material to blur — it just renders as grey haze. An explicit surface is
                // both cleaner and keeps the title legible over any first swatch.
                .toolbarBackground(Color(.systemBackground), for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { accountIsPresented = true } label: {
                            ToolbarIcon("person.circle")
                        }
                        .accessibilityLabel("Account")
                    }
                    // Extracting from a photo is the app's primary entry point, so it stays one
                    // tap away here as well as inside the Tools sheet. Reaching it only through
                    // Tools buries the main thing the app does. It leads Export because input
                    // comes before output.
                    ToolbarItem(placement: .topBarTrailing) {
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            ToolbarIcon("photo.badge.plus")
                        }
                        .accessibilityLabel("Extract colors from a photo")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        exportMenu
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        }
        .photosPicker(isPresented: $photoPickerIsPresented, selection: $selectedItem, matching: .images)
        .onChange(of: selectedItem) { _, item in
            guard let item else { return }
            extract(item)
        }
        .sheet(isPresented: $toolsArePresented) {
            ToolsSheet { open($0) }
        }
        .sheet(isPresented: $contrastIsPresented) {
            WCAGCheckerView(palette: store.palette)
        }
        .sheet(isPresented: $accountIsPresented) {
            AccountView()
        }
        .sheet(item: $detailSwatch) { swatch in
            ColorDetailView(swatch: swatch)
        }
    }

    // MARK: - Chrome

    private var title: String {
        store.isShowingDefault ? "ColorSense" : "Your palette"
    }

    /// Floating glass capsules rather than a filled bar, so the palette stays the full screen and
    /// the controls read as sitting on top of it. Both hug their content instead of splitting the
    /// width — two stretched slabs was the least compact arrangement available.
    private var bottomBar: some View {
        HStack(spacing: 10) {
            Button { toolsArePresented = true } label: {
                Label("Tools", systemImage: "square.grid.2x2")
                    .font(BrandFont.ui(15, weight: .medium))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay {
                        Capsule().strokeBorder(.primary.opacity(0.12), lineWidth: 0.5)
                    }
            }
            // Without .plain the button's tint repaints the label system-blue, overriding
            // the neutral foreground this secondary control is supposed to have.
            .buttonStyle(.plain)

            generateButton
        }
        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
        .padding(.top, 10)
        .frame(maxWidth: .infinity)
        // Continue the last swatch behind the bar instead of letting a slab of system chrome
        // show through. The palette reads as running to the bottom edge, but the bar still
        // reserves its own space so it never covers that swatch's label.
        .background {
            (store.palette.colors.last?.color ?? Color(.systemBackground))
                .ignoresSafeArea(edges: .bottom)
        }
    }

    /// Regenerates the unlocked swatches. No count is surfaced: the run never dead-ends, it just
    /// shifts to bolder schemes past `PaletteGenerator.wideningIteration`, so a number would be
    /// noise rather than information.
    private var generateButton: some View {
        Button {
            store.generate()
        } label: {
            Label("Generate", systemImage: "arrow.triangle.2.circlepath")
                .font(BrandFont.ui(15, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(BrandColor.coral, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var exportMenu: some View {
        Menu {
            Button {
                UIPasteboard.general.string = PaletteExportService.hexList(store.palette)
            } label: {
                Label("Copy hex codes", systemImage: "number")
            }
            Button {
                UIPasteboard.general.string = PaletteExportService.cssVariables(store.palette)
            } label: {
                Label("Copy CSS variables", systemImage: "curlybraces")
            }
            if let image = PaletteExportService.image(for: store.palette) {
                ShareLink(item: image, preview: SharePreview("ColorSense palette", image: image)) {
                    Label("Share as image", systemImage: "photo")
                }
            }
        } label: {
            // Nudged down because the share glyph's arrow extends above its baseline box, so
            // centering it against the other toolbar icons leaves it visibly high.
            ToolbarIcon("square.and.arrow.up", baselineNudge: 1)
        }
    }

    private var extractingOverlay: some View {
        ZStack {
            Color.black.opacity(0.45)
            VStack(spacing: 12) {
                ProgressView().tint(.white)
                Text("Extracting colors\u{2026}")
                    .font(BrandFont.ui(15))
                    .foregroundStyle(.white)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Actions

    private func open(_ tool: Tool) {
        switch tool {
        case .extractor: photoPickerIsPresented = true
        case .contrast: contrastIsPresented = true
        }
    }

    private func extract(_ item: PhotosPickerItem) {
        Task {
            isExtracting = true
            defer {
                isExtracting = false
                selectedItem = nil
            }
            if let palette = await PhotoExtractor.palette(from: item) {
                store.replace(with: palette)
            }
        }
    }
}

/// Toolbar glyphs at one size in one box. SF Symbols have different bounding boxes — the share
/// glyph is taller than the photo one — so laying them out raw leaves them visibly unaligned.
/// A view rather than a method on `RootView` so it can be built inside `PhotosPicker` and `Menu`
/// label closures, which are not main-actor isolated.
private struct ToolbarIcon: View {
    let systemName: String
    var baselineNudge: CGFloat = 0

    init(_ systemName: String, baselineNudge: CGFloat = 0) {
        self.systemName = systemName
        self.baselineNudge = baselineNudge
    }

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 17, weight: .regular))
            .frame(width: 26, height: 26)
            .offset(y: baselineNudge)
    }
}

#Preview("Extracted") {
    RootView().environment(PaletteStore())
}
