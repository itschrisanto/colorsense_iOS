import SwiftUI
import ClerkKit
import ClerkKitUI

/// The app's home screen: whatever palette the user last had. There is no separate landing or
/// upload screen — extracting from a photo is a tool that replaces this palette, not a place you
/// go first. First launch lands on the brand palette rather than an empty state.
struct RootView: View {
    @Environment(PaletteStore.self) private var store
    @Environment(Clerk.self) private var clerk

    /// Separate from `PaletteStore.isShowingDefault`: somebody may deliberately keep exploring
    /// the supplied brand palette, and that should not make onboarding return next launch.
    @AppStorage("onboarding.completed.v1") private var onboardingCompleted = false
    @State private var forcedOnboardingDismissed = false

    @State private var toolWorkspaceIsPresented = false
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
    /// Presents `PhotoSourcePicker`, which is the only way into extraction. Extractor remains the
    /// dock's central action rather than a panel because it replaces the palette and returns.
    @State private var sourceChoiceIsPresented = ProcessInfo.processInfo.arguments.contains("-photo-source")
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
        ZStack {
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
            // Onboarding covers the palette completely, so the bands must not remain a second,
            // invisible navigation tree for VoiceOver underneath it.
            .accessibilityHidden(shouldShowOnboarding)

            if shouldShowOnboarding {
                OnboardingFlowView(onComplete: finishOnboarding)
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        // One screen for both sources — recent photos as a grid with the camera as its first
        // cell — rather than asking which source before showing either. PhotoSourcePicker owns
        // the camera, the library and every permission state between them.
        // Extraction is an action that replaces the palette, not a panel in the tool workspace.
        .sheet(isPresented: $sourceChoiceIsPresented) {
            PhotoSourcePicker { extract($0) }
        }
        .onChange(of: sourceChoiceIsPresented) { was, now in
            diagLog("sheet binding \(was) -> \(now)")
        }
        .onChange(of: isExtracting) { _, now in
            diagLog("isExtracting -> \(now)")
        }
        .fullScreenCover(isPresented: $toolWorkspaceIsPresented) {
            ToolWorkspaceView(isPro: isPro)
        }
        // Always `AccountView`, never `AuthView` directly.
        //
        // Signed out this used to present Clerk's `AuthView` straight away, to save a tap. That
        // saving is what broke it: `AuthView` derives every field from
        // `clerk.environment?.enabledFirstFactorAttributes`, so a nil environment renders an empty
        // screen with no error and nothing to press, and the dock behind it is unreachable. The
        // Clerk environment failing to load is not hypothetical here; the whole proxy exists
        // because that host does not complete a TLS handshake.
        //
        // `AccountView` always has content, offers sign-in itself, and can always be dismissed.
        .sheet(isPresented: $accountIsPresented) {
            AccountView()
        }
        .sheet(item: $detailSwatch) { swatch in
            ColorDetailView(isPro: isPro, swatch: swatch)
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
            SavePaletteView(palette: store.palette, isPro: isPro) { name in
                showToast("Saved “\(name)” to your account")
            }
        }
        .sheet(item: $addColorDestination) { destination in
            AddColorView(
                insertionIndex: destination.index,
                initialSwatch: destination.suggestedSwatch,
                isPro: isPro
            )
        }
        // A soft tap on Generate: the whole screen recolours at once, and a light physical
        // confirmation makes that land as something you did rather than something that happened.
        .sensoryFeedback(.impact(flexibility: .soft), trigger: generateTaps)
        // Keyed on the session, not just on appear.
        //
        // A bare `.task` runs as this view appears, which at a cold launch is *before* Clerk has
        // restored the session. `authorizedRequest` then fails with `.notSignedIn`, the plan reads
        // as free, and nothing retried it until the account sheet happened to close. A Pro account
        // was therefore locked out of every Pro feature on every cold launch. It went unnoticed
        // because the older Pro features degrade quietly; SVG Recolor is gated outright, so it
        // surfaced there first.
        //
        // Keying on the user id means this runs again the moment the session arrives, and again
        // when it goes away.
        .task(id: clerk.user?.id) { await refreshPlan() }
        .onChange(of: accountIsPresented) { _, isPresented in
            if !isPresented { Task { await refreshPlan() } }
        }
    }

    // MARK: - Chrome


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

    /// A single floating glass dock holding every action, so the palette owns the whole screen
    /// and there is no top bar at all. Adding a photo sits in the centre and is the only coral
    /// item: it is the app's entry point, and an icon-only row needs one clear focal point or it
    /// reads as five equal-weight mystery glyphs.
    ///
    /// Generate deliberately does *not* also take an accent — two competing highlights in a
    /// five-item row leaves neither reading as primary.
    ///
    /// It carries no captions. Labelling it was tried, to make it match the tool strip, and the
    /// match was made in the wrong direction: this is the app's settled bar and the strip is what
    /// should look like it. `dockCapsule` is where the two now share a definition.
    private var dock: some View {
        HStack(spacing: 0) {
            exportMenu

            DockButton("square.grid.2x2", label: "Tools", foreground: dockForeground) {
                toolWorkspaceIsPresented = true
            }

            Button {
                // The discriminating trace. If this line lands immediately before an unexpected
                // `sheet binding false -> true`, a real second activation of this button is
                // reopening the picker. If the binding flips with no line here, SwiftUI is
                // re-presenting on its own and the ordering inside choose(_:) is the suspect.
                diagLog("dock plus action, tap=\(plusTaps + 1)")
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
        .dockCapsule(foreground: dockForeground)
        // Continue the last swatch behind the dock instead of letting a slab of system chrome
        // show through. The palette reads as running to the bottom edge, but the dock still
        // reserves its own space so it never covers that swatch's label.
        .background {
            (store.palette.colors.last?.color ?? Color(.systemBackground))
                .ignoresSafeArea(edges: .bottom)
        }
    }

    /// The share button. Opens `ShareSheet` rather than a `Menu` so its destinations have room for
    /// explanatory copy instead of inheriting iOS's compact default menu chrome.
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

    /// `-show-onboarding` makes iteration possible without repeatedly deleting app data. It is a
    /// launch-only development affordance: completing the forced flow hides it for this process,
    /// while a real first launch writes the same durable completion flag production will use.
    private var shouldShowOnboarding: Bool {
        let isForced = ProcessInfo.processInfo.arguments.contains("-show-onboarding")
        return (!onboardingCompleted || isForced) && !forcedOnboardingDismissed
    }

    private func finishOnboarding() {
        onboardingCompleted = true
        withAnimation(OnboardingMotion.beat(reduceMotion: reduceMotion)) {
            forcedOnboardingDismissed = true
        }
    }

    /// Reads the plan, and is careful about what a failure means.
    ///
    /// Signed out is a definite answer: no account, no Pro. A *failed request* while signed in is
    /// not an answer at all, and treating it as one used to drop a paying reader to free on any
    /// blip. So a failure now leaves the last known value alone rather than revoking Pro over a
    /// dropped connection.
    private func refreshPlan() async {
        guard clerk.user != nil else {
            isPro = false
            return
        }
        if case .success(let plan) = await SavedPaletteService.currentPlan() {
            isPro = plan == "pro" || plan == "business"
        }
    }

    /// Extraction from whichever source the picker used. Both arrive already decoded — the
    /// picker owns loading and reports its own read failures — so there is nothing left to fail
    /// here and no palette-unchanged case to explain.
    private func extract(_ image: UIImage) {
        diagLog("extract() called")
        Task {
            isExtracting = true
            defer { isExtracting = false }
            diagLog("extraction starting")
            let extracted = await PhotoExtractor.palette(from: image)
            diagLog("extraction done, \(extracted.colors.count) colors")
            withAnimation(PaletteMotion.replace(reduceMotion: reduceMotion)) {
                store.replace(with: extracted)
            }
            diagLog("palette replaced")
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

#Preview("Extracted") {
    RootView().environment(PaletteStore())
}
