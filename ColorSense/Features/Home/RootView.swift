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
    @State private var addColorDestination: AddColorDestination?
    @State private var toast: String?
    /// Pro users get a logo-free share card. Defaults to false so the lockup is included
    /// whenever the plan is unknown — offline, signed out, or a failed lookup. Giving a Pro user
    /// a branded export occasionally is a smaller cost than handing free users the paid feature
    /// every time the network hiccups.
    @State private var isPro = false
    @State private var pendingRemoval: PaletteStore.Removal?
    /// Counts Generate taps purely to drive haptics. Watching `palette.generation` instead would
    /// also fire on extraction, which resets it to zero — a change, but not a tap.
    @State private var generateTaps = 0

    var body: some View {
        NavigationStack {
            PaletteBandsView(
                palette: store.palette,
                onToggleLock: { store.toggleLock(for: $0) },
                onAddColor: { index in
                    guard store.palette.colors.count < PaletteStore.maximumColorCount else {
                        showToast("A palette can contain up to 8 colors")
                        return
                    }
                    addColorDestination = AddColorDestination(
                        index: index,
                        suggestedSwatch: suggestedColor(at: index)
                    )
                },
                onDelete: { removeColor($0) },
                onOpenDetail: { detailSwatch = $0 }
            )
                .overlay { if isExtracting { extractingOverlay } }
                .overlay(alignment: .top) { if let toast { toastView(toast) } }
                // No nav bar: with every action in the dock it would hold nothing but a title,
                // and a whole bar of chrome for one label is space the palette can use. The
                // bands still respect the top safe area, so the status bar keeps a clean strip
                // to sit on rather than landing on an arbitrary swatch.
                .toolbar(.hidden, for: .navigationBar)
                .safeAreaInset(edge: .bottom, spacing: 0) { dock }
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
        .sheet(item: $addColorDestination) { destination in
            AddColorView(
                insertionIndex: destination.index,
                initialSwatch: destination.suggestedSwatch
            )
        }
        // A soft tap on Generate: the whole screen recolours at once, and a light physical
        // confirmation makes that land as something you did rather than something that happened.
        .sensoryFeedback(.impact(flexibility: .soft), trigger: generateTaps)
        // Refreshed on launch and whenever the account sheet closes, since signing in or out
        // there is the only thing in the app that can change the plan.
        .task { await refreshPlan() }
        .onChange(of: accountIsPresented) { _, isPresented in
            if !isPresented { Task { await refreshPlan() } }
        }
    }

    // MARK: - Chrome


    /// A single floating glass dock holding every action, so the palette owns the whole screen
    /// and there is no top bar at all. Adding a photo sits in the centre and is the only coral
    /// item: it is the app's entry point, and an icon-only row needs one clear focal point or it
    /// reads as five equal-weight mystery glyphs.
    ///
    /// Generate deliberately does *not* also take an accent — two competing highlights in a
    /// five-item row leaves neither reading as primary.
    private var dock: some View {
        HStack(spacing: 0) {
            exportMenu

            DockButton("square.grid.2x2", label: "Tools") { toolsArePresented = true }

            PhotosPicker(selection: $selectedItem, matching: .images) {
                DockIcon("plus", size: 21)
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(BrandColor.coral, in: Circle())
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Extract colors from a photo")

            DockButton("arrow.triangle.2.circlepath", label: "Generate") {
                store.generate()
                generateTaps += 1
            }

            DockButton("person.circle", label: "Account") { accountIsPresented = true }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay { Capsule().strokeBorder(.primary.opacity(0.14), lineWidth: 0.5) }
        .shadow(color: .black.opacity(0.2), radius: 14, y: 5)
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .frame(maxWidth: .infinity)
        // Continue the last swatch behind the dock instead of letting a slab of system chrome
        // show through. The palette reads as running to the bottom edge, but the dock still
        // reserves its own space so it never covers that swatch's label.
        .background {
            (store.palette.colors.last?.color ?? Color(.systemBackground))
                .ignoresSafeArea(edges: .bottom)
        }
    }

    /// Save and Share are two different destinations, and the labels have to say which:
    /// **Save** puts the palette in the user's ColorSense *account* (same store as the web app),
    /// **Share as image** hands it to the *device* — share sheet or camera roll.
    private var exportMenu: some View {
        Menu {
            Button {
                Task {
                    switch await SavedPaletteService.save(store.palette) {
                    case .success: showToast("Saved to your account")
                    case .failure(.notSignedIn): accountIsPresented = true
                    case .failure(let error): showToast(error.message)
                    }
                }
            } label: {
                Label("Save to my account", systemImage: "bookmark")
            }

            Section {
                if let shareable = PaletteExportService.shareable(
                    for: store.palette,
                    includesLogo: !isPro
                ) {
                    ShareLink(
                        item: shareable,
                        preview: SharePreview("ColorSense palette", image: shareable.preview)
                    ) {
                        Label("Share as image", systemImage: "square.and.arrow.up")
                    }
                }
                Button {
                    UIPasteboard.general.string = PaletteExportService.hexList(store.palette)
                    showToast("Hex codes copied")
                } label: {
                    Label("Copy hex codes", systemImage: "number")
                }
                Button {
                    UIPasteboard.general.string = PaletteExportService.cssVariables(store.palette)
                    showToast("CSS variables copied")
                } label: {
                    Label("Copy CSS variables", systemImage: "curlybraces")
                }
            }
        } label: {
            // The share glyph's rising arrow makes it taller than the rest, which leaves its
            // ink centre sitting 1pt below theirs at the same point size. Measured, not guessed:
            // crop the dock from a screenshot, threshold the dark pixels inside the capsule, and
            // compare each glyph's bounding-box centre.
            DockIcon("square.and.arrow.up", opticalOffset: -1)
                .frame(maxWidth: .infinity)
                .contentShape(.rect)
        }
        // Menu ignores .buttonStyle(.plain), so without an explicit tint its glyph renders
        // system-blue while every other dock icon is neutral.
        .tint(.primary)
        .accessibilityLabel("Share and export")
    }

    /// Brief confirmation for actions with no visible result of their own, like saving to Photos.
    private func toastView(_ message: String) -> some View {
        HStack(spacing: 12) {
            Text(message)
                .font(BrandFont.ui(14, weight: .medium))
            if pendingRemoval != nil {
                Button("Undo") { undoRemoval() }
                    .font(BrandFont.ui(14, weight: .bold))
                    .foregroundStyle(BrandColor.coral)
            }
        }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay { Capsule().strokeBorder(.primary.opacity(0.12), lineWidth: 0.5) }
            .shadow(color: .black.opacity(0.15), radius: 10, y: 3)
            .padding(.top, 10)
            .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func showToast(_ message: String, removal: PaletteStore.Removal? = nil) {
        pendingRemoval = removal
        withAnimation(.snappy) { toast = message }
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            withAnimation(.snappy) {
                if toast == message {
                    toast = nil
                    pendingRemoval = nil
                }
            }
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

    private func refreshPlan() async {
        if case .success(let plan) = await SavedPaletteService.currentPlan() {
            isPro = plan == "pro" || plan == "business"
        } else {
            isPro = false
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

    private func removeColor(_ swatchID: PaletteColor.ID) {
        guard let removal = store.remove(swatchID: swatchID) else { return }
        showToast("Color removed", removal: removal)
    }

    /// Start the editor with a color related to the seam the user tapped instead of always
    /// presenting the brand coral. It is only a suggestion; the wheel and hex field remain the
    /// source of truth for what is inserted.
    private func suggestedColor(at requestedIndex: Int) -> PaletteColor {
        let colors = store.palette.colors
        let index = min(max(requestedIndex, 0), colors.count)

        if index > 0, index < colors.count {
            let before = colors[index - 1]
            let after = colors[index]
            return PaletteColor(
                red: (before.red + after.red) / 2,
                green: (before.green + after.green) / 2,
                blue: (before.blue + after.blue) / 2,
                dominance: 0
            )
        }

        if index > 0 { return colors[index - 1] }
        if let first = colors.first { return first }
        return PaletteColor(hex: 0x808080, dominance: 0)
    }

    private func undoRemoval() {
        guard let pendingRemoval else { return }
        store.restore(pendingRemoval)
        withAnimation(.snappy) { toast = nil }
        self.pendingRemoval = nil
    }
}

private struct AddColorDestination: Identifiable {
    let index: Int
    let suggestedSwatch: PaletteColor
    var id: Int { index }
}

/// Dock glyphs normalised into one box.
///
/// SF Symbols have different bounding boxes — `square.and.arrow.up` is taller than the others
/// because of its rising arrow — so setting them at a common font size still leaves them
/// optically misaligned (measured: 2.7pt apart). Scaling each symbol to fit the same square makes
/// the centering structural instead of a per-symbol fudge factor.
///
/// A view rather than a method on `RootView` so it can be built inside `PhotosPicker` and `Menu`
/// label closures, which are not main-actor isolated.
private struct DockIcon: View {
    let systemName: String
    var size: CGFloat = 19
    /// Residual correction for symbols whose *ink* sits off-centre inside their own layout box,
    /// which scaling cannot fix. Measure it from a screenshot rather than eyeballing: crop the
    /// dock, threshold the dark pixels, and compare each glyph's bounding-box centre.
    var opticalOffset: CGFloat = 0

    nonisolated init(_ systemName: String, size: CGFloat = 21, opticalOffset: CGFloat = 0) {
        self.systemName = systemName
        self.size = size
        self.opticalOffset = opticalOffset
    }

    var body: some View {
        // Point size, not a normalised box: SF Symbols are drawn to look balanced against each
        // other at a common point size, and scaling each to fit an identical square undoes that
        // — it renders tall glyphs like the share icon visibly narrower than the rest.
        Image(systemName: systemName)
            .font(.system(size: size, weight: .regular))
            .offset(y: opticalOffset)
            .frame(height: 46)
    }
}

/// One neutral action in the dock. `.plain` keeps the button's tint from repainting the glyph
/// system-blue over the glass.
private struct DockButton: View {
    let systemName: String
    let label: String
    let action: () -> Void

    init(_ systemName: String, label: String, action: @escaping () -> Void) {
        self.systemName = systemName
        self.label = label
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            DockIcon(systemName)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .contentShape(.rect)
        }
        .buttonStyle(DockButtonStyle())
        .accessibilityLabel(label)
    }
}

/// Lights a glass capsule behind whichever dock item is being pressed. iOS has no hover on
/// touch, so the press state is the only moment there is to acknowledge — without it, an
/// icon-only dock gives no feedback that a tap landed.
///
/// Also stands in for `.plain`: the default style tints its label system-blue, which would
/// leave the dock glyphs the wrong colour.
struct DockButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay { Capsule().strokeBorder(.primary.opacity(0.14), lineWidth: 0.5) }
                    .opacity(configuration.isPressed ? 1 : 0)
            }
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview("Extracted") {
    RootView().environment(PaletteStore())
}
