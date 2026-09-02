import SwiftUI
import ClerkKit
import ClerkKitUI

/// The app's home screen: whatever palette the user last had. There is no separate landing or
/// upload screen — extracting from a photo is a tool that replaces this palette, not a place you
/// go first. First launch lands on the brand palette rather than an empty state.
struct RootView: View {
    @Environment(PaletteStore.self) private var store
    @Environment(Clerk.self) private var clerk

    @State private var toolsArePresented = false
    @State private var contrastIsPresented = false
    @State private var accountIsPresented = false
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
    @State private var savePaletteIsPresented = false
    @State private var shareIsPresented = false
    @State private var libraryIsPresented = false
    @State private var healthIsPresented = false
    /// Presents `PhotoSourcePicker`, which is now the only way into an extraction — from the
    /// dock's + and from the Tools sheet's Extractor alike.
    @State private var sourceChoiceIsPresented = false
    /// Counts Generate taps purely to drive haptics. Watching `palette.generation` instead would
    /// also fire on extraction, which resets it to zero — a change, but not a tap.
    @State private var generateTaps = 0
    /// Drives the + button's quarter turn. A counter rather than a bool so every tap spins
    /// again in the same direction instead of rocking back and forth.
    @State private var plusTaps = 0
    /// Motion is opt-out at the system level and `withAnimation` ignores it, so every palette
    /// change reads this and passes nil when it is on. See PaletteMotion.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                onOpenDetail: { detailSwatch = $0 },
                onMove: { from, to in
                    store.move(from: from, to: to)
                    AnalyticsService.capture(.colorReordered)
                }
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
        // One screen for both sources — recent photos as a grid with the camera as its first
        // cell — rather than asking which source before showing either. PhotoSourcePicker owns
        // the camera, the library and every permission state between them.
        .sheet(isPresented: $sourceChoiceIsPresented) {
            PhotoSourcePicker { extract($0) }
        }
        .sheet(isPresented: $toolsArePresented) {
            ToolsSheet { open($0) }
        }
        .sheet(isPresented: $contrastIsPresented) {
            WCAGCheckerView(palette: store.palette)
        }
        .sheet(isPresented: $accountIsPresented) {
            // Signed out, the account screen had nothing on it but a button that opened this —
            // so open it directly and save the extra tap.
            if clerk.user == nil {
                AuthView()
                    // Same local mark AccountView used: Clerk's dashboard logo is a light-only
                    // bitmap on an opaque white canvas, which looks wrong in dark mode.
                    .clerkAppIconView { ColorSenseAuthLogo() }
            } else {
                AccountView()
            }
        }
        .sheet(item: $detailSwatch) { swatch in
            ColorDetailView(swatch: swatch)
        }
        .sheet(isPresented: $libraryIsPresented) {
            LibraryView()
        }
        .sheet(isPresented: $healthIsPresented) {
            PaletteHealthView(palette: store.palette)
        }
        .sheet(isPresented: $shareIsPresented) {
            ShareSheet(
                palette: store.palette,
                shareable: PaletteExportService.shareable(
                    for: store.palette,
                    includesLogo: !isPro
                ),
                isPro: isPro,
                onSaveToAccount: {
                    // Signing in is a prerequisite, so check it before asking for a name —
                    // otherwise the user types one only to be bounced to auth and lose it.
                    if clerk.user == nil {
                        accountIsPresented = true
                    } else {
                        savePaletteIsPresented = true
                    }
                },
                onCopied: { showToast($0) }
            )
        }
        .sheet(isPresented: $savePaletteIsPresented) {
            SavePaletteView(palette: store.palette) { name in
                showToast("Saved “\(name)” to your account")
            }
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
    /// Black or white against the swatch the dock floats on, by the same WCAG rule the band labels
    /// use — `ContrastCalculator`, via `PaletteColor.legibleForeground`.
    ///
    /// Without it the glyphs followed the *system* appearance while their background followed the
    /// *palette*, which are independent: in dark mode over a pale last swatch the dock painted
    /// white glyphs on a near-white ground. Measured off the framebuffer at 2.36:1, against
    /// 10.42:1 for the same dock in light mode — and the band label directly above it was
    /// correctly flipping to black at the time.
    private var dockForeground: Color {
        store.palette.colors.last?.legibleForeground ?? .primary
    }

    private var dock: some View {
        HStack(spacing: 0) {
            exportMenu

            DockButton("square.grid.2x2", label: "Tools", foreground: dockForeground) { toolsArePresented = true }

            Button {
                plusTaps += 1
                sourceChoiceIsPresented = true
            } label: {
                DockIcon("plus", size: 21)
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(Double(plusTaps) * 90))
                    .animation(ControlMotion.spin(reduceMotion: reduceMotion), value: plusTaps)
                    .frame(width: 46, height: 46)
                    .background(BrandColor.coral, in: Circle())
            }
            .buttonStyle(PlusButtonStyle())
            .frame(maxWidth: .infinity)
            .accessibilityLabel("New palette from a photo")

            DockButton("arrow.triangle.2.circlepath", label: "Generate", foreground: dockForeground) {
                withAnimation(PaletteMotion.recolor(reduceMotion: reduceMotion)) {
                    store.generate()
                }
                AnalyticsService.capture(.paletteGenerated, ["colors": store.palette.colors.count])
                generateTaps += 1
            }

            // Shows the user's own picture once signed in — a generic glyph gives no sense of
            // whose account is attached.
            Button { accountIsPresented = true } label: {
                Group {
                    if let user = clerk.user, user.hasImage, let url = URL(string: user.imageUrl) {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            DockIcon("person.circle").foregroundStyle(dockForeground)
                        }
                        .frame(width: 26, height: 26)
                        .clipShape(Circle())
                        .overlay { Circle().strokeBorder(dockForeground.opacity(0.18), lineWidth: 1) }
                        .frame(height: 46)
                    } else {
                        DockIcon("person.circle").foregroundStyle(dockForeground)
                    }
                }
                .frame(maxWidth: .infinity)
                .contentShape(.rect)
            }
            .buttonStyle(DockButtonStyle(foreground: dockForeground))
            .accessibilityLabel("Account")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay { Capsule().strokeBorder(dockForeground.opacity(0.14), lineWidth: 0.5) }
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

    /// The share button. Opens `ShareSheet` rather than a `Menu` so it matches the Tools sheet
    /// instead of iOS's default menu chrome.
    private var exportMenu: some View {
        Button {
            shareIsPresented = true
        } label: {
            // The share glyph's rising arrow makes it taller than the rest, which leaves its
            // ink centre sitting 1pt below theirs at the same point size. Measured, not guessed:
            // crop the dock from a screenshot, threshold the dark pixels inside the capsule, and
            // compare each glyph's bounding-box centre.
            DockIcon("square.and.arrow.up", opticalOffset: -1)
                .foregroundStyle(dockForeground)
                .frame(maxWidth: .infinity)
                .contentShape(.rect)
        }
        .buttonStyle(DockButtonStyle(foreground: dockForeground))
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
        AnalyticsService.capture(.toolOpened, ["tool": tool.rawValue])
        switch tool {
        case .extractor: sourceChoiceIsPresented = true
        case .contrast: contrastIsPresented = true
        case .health: healthIsPresented = true
        case .library: libraryIsPresented = true
        }
    }

    private func refreshPlan() async {
        if case .success(let plan) = await SavedPaletteService.currentPlan() {
            isPro = plan == "pro" || plan == "business"
        } else {
            isPro = false
        }
    }

    /// Extraction from whichever source the picker used. Both arrive already decoded — the
    /// picker owns loading and reports its own read failures — so there is nothing left to fail
    /// here and no palette-unchanged case to explain.
    private func extract(_ image: UIImage) {
        Task {
            isExtracting = true
            defer { isExtracting = false }
            let extracted = await PhotoExtractor.palette(from: image)
            withAnimation(PaletteMotion.replace(reduceMotion: reduceMotion)) {
                store.replace(with: extracted)
            }
        }
    }

    private func removeColor(_ swatchID: PaletteColor.ID) {
        var removal: PaletteStore.Removal?
        withAnimation(PaletteMotion.structural(reduceMotion: reduceMotion)) {
            removal = store.remove(swatchID: swatchID)
        }
        guard let removal else { return }
        AnalyticsService.capture(.colorRemoved)
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
        withAnimation(PaletteMotion.structural(reduceMotion: reduceMotion)) {
            store.restore(pendingRemoval)
        }
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
/// A view rather than a method on `RootView` so it can be built inside a `Button` label
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
    let foreground: Color
    let action: () -> Void

    init(_ systemName: String, label: String, foreground: Color, action: @escaping () -> Void) {
        self.systemName = systemName
        self.label = label
        self.foreground = foreground
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            DockIcon(systemName)
                .frame(maxWidth: .infinity)
                .contentShape(.rect)
        }
        .buttonStyle(DockButtonStyle(foreground: foreground))
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
    let foreground: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay { Capsule().strokeBorder(foreground.opacity(0.14), lineWidth: 0.5) }
                    .opacity(configuration.isPressed ? 1 : 0)
            }
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview("Extracted") {
    RootView().environment(PaletteStore())
}
