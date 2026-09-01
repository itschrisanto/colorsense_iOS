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
                // The bands run edge to edge, so the bar needs its own opaque surface. Without an
                // explicit color the glass toolbar tints itself from the first swatch, which
                // leaves the title unreadable whenever that swatch is dark.
                .toolbarBackground(Color(.systemBackground), for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { accountIsPresented = true } label: {
                            Image(systemName: "person.circle")
                        }
                        .accessibilityLabel("Account")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        exportMenu
                    }
                    // Extracting from a photo is the app's primary entry point, so it stays one
                    // tap away here as well as inside the Tools sheet. Reaching it only through
                    // Tools buries the main thing the app does.
                    ToolbarItem(placement: .topBarTrailing) {
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            Image(systemName: "photo.badge.plus")
                        }
                        .accessibilityLabel("Extract colors from a photo")
                    }
                }
                .safeAreaInset(edge: .bottom) { bottomBar }
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

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button { toolsArePresented = true } label: {
                Label("Tools", systemImage: "square.grid.2x2")
                    .font(BrandFont.ui(15, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.secondarySystemBackground))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            // Without .plain the button's tint repaints the label system-blue, overriding
            // the neutral foreground this secondary control is supposed to have.
            .buttonStyle(.plain)

            generateButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
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
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(BrandColor.coral)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
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
            Image(systemName: "square.and.arrow.up")
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

#Preview("Extracted") {
    RootView().environment(PaletteStore())
}
