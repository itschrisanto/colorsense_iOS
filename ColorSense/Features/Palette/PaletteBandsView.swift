import SwiftUI

/// The palette rendered as full-bleed bands splitting the available height, matching the web
/// app's mobile layout. Tapping a band opens its detail card; the lock button keeps a swatch
/// through Generate.
struct PaletteBandsView: View {
    let palette: ExtractedPalette
    let onToggleLock: (PaletteColor.ID) -> Void
    let onAddColor: (Int) -> Void
    let onDelete: (PaletteColor.ID) -> Void
    let onOpenDetail: (PaletteColor) -> Void

    /// Hex of the swatch most recently copied, so its button can confirm with a checkmark.
    @State private var copiedHex: String?
    /// One counter per seam, so spinning one + does not spin the others.
    @State private var seamTaps: [Int: Int] = [:]
    /// Bumped on a completed swipe, purely to fire a haptic.
    @State private var swipeDeletes = 0
    /// Band width, for the swipe threshold. Read from a background reader rather than wrapping
    /// the stack in a GeometryReader, which would change how the bands are laid out.
    @State private var bandWidth: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ForEach(palette.colors) { swatch in
                    band(swatch, width: bandWidth)
                }
            }

            if palette.colors.count < PaletteStore.maximumColorCount {
                GeometryReader { proxy in
                    ForEach(insertionIndices, id: \.self) { index in
                        insertionButton(at: index)
                            .position(
                                x: proxy.size.width / 2,
                                y: insertionY(for: index, height: proxy.size.height)
                            )
                    }
                }
            }
        }
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { bandWidth = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, width in bandWidth = width }
            }
        }
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: swipeDeletes)
        // The bands neither scroll nor grow — the palette fixes their height — so text that keeps
        // growing collides with the band below rather than pushing it. Measured at
        // accessibility-extra-large, uncapped names truncated to "Governor…" and "Cocoa Be…".
        //
        // A constant is enough because the app is portrait-only (see UISupportedInterfaceOrientations
        // in project.yml). The tightest portrait case is eight colors on the smallest device this
        // ships to, which still leaves about 70pt a band against the 68pt this cap allows. Landscape
        // was the case that needed the height to be measured, and it is no longer reachable — if a
        // landscape or iPad layout is ever added, this has to become a function of the space actually
        // available, because there the bands could not fit at any text size at all.
        //
        // The limit is width-driven rather than height-driven: past accessibility1 a long name like
        // "Governor Bay" truncates against the action buttons while the height is still fine. Every
        // other screen scrolls, so none of them caps.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private var insertionIndices: [Int] {
        palette.colors.count == 1 ? [1] : Array(1..<palette.colors.count)
    }

    private func insertionY(for index: Int, height: CGFloat) -> CGFloat {
        guard palette.colors.count > 1 else { return max(22, height - 22) }
        return height * CGFloat(index) / CGFloat(palette.colors.count)
    }

    private func insertionButton(at index: Int) -> some View {
        Button {
            seamTaps[index, default: 0] += 1
            onAddColor(index)
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .semibold))
                .rotationEffect(.degrees(Double(seamTaps[index] ?? 0) * 90))
                .animation(ControlMotion.spin(reduceMotion: reduceMotion), value: seamTaps[index])
                .frame(width: 30, height: 30)
                .background(.ultraThinMaterial, in: Circle())
                .overlay { Circle().strokeBorder(.primary.opacity(0.16), lineWidth: 0.5) }
                .shadow(color: .black.opacity(0.16), radius: 4, y: 1)
                .contentShape(Circle())
        }
        .buttonStyle(PlusButtonStyle())
        .frame(width: 44, height: 44)
        .accessibilityLabel(insertionAccessibilityLabel(at: index))
    }

    private func insertionAccessibilityLabel(at index: Int) -> String {
        guard palette.colors.count > 1,
              palette.colors.indices.contains(index - 1),
              palette.colors.indices.contains(index)
        else { return "Add color to palette" }
        return "Add color between \(palette.colors[index - 1].name) and \(palette.colors[index].name)"
    }

    /// A band can only be swiped away while the palette is above its minimum, matching the trash
    /// button, which hides for the same reason.
    private var canRemove: Bool {
        palette.colors.count > PaletteStore.minimumColorCount
    }

    private func band(_ swatch: PaletteColor, width: CGFloat) -> some View {
        SwipeToRemove(
            width: width,
            isEnabled: canRemove,
            onRemove: {
                swipeDeletes += 1
                onDelete(swatch.id)
            }
        ) {
            bandBody(swatch, width: width)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Show color details") { onOpenDetail(swatch) }
        // VoiceOver cannot perform a swipe, so the same action is offered directly. The trash
        // button is also still there for everyone.
        .accessibilityAction(named: "Remove \(swatch.name)") {
            if canRemove {
                swipeDeletes += 1
                onDelete(swatch.id)
            }
        }
    }

    private func bandBody(_ swatch: PaletteColor, width: CGFloat) -> some View {
        HStack(spacing: 12) {
            // Name leads, hex supports it — a name is the thing worth reading at a glance, and
            // this matches the exported share card, which also puts the name over the hex.
            VStack(alignment: .leading, spacing: 3) {
                // The band keeps its identity through Generate so its colour can interpolate,
                // which means the label and hex are re-rendered in place with new values. A
                // cross-fade keeps them in step with the colour behind them; without it the text
                // swaps instantly against a band that is still moving.
                Text(swatch.name)
                    .font(BrandFont.ui(24, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.opacity)
                Text(swatch.hex)
                    .brandMono(14, weight: .medium)
                    .opacity(0.75)
                    .contentTransition(.opacity)
            }
            Spacer()
            bandActions(for: swatch)
        }
        .foregroundStyle(swatch.legibleForeground)
        .padding(.leading, 20)
        .padding(.trailing, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(swatch.color)
        // A tap gesture rather than wrapping the row in a Button, so the lock button inside
        // stays independently tappable.
        .contentShape(.rect)
        .onTapGesture { onOpenDetail(swatch) }
    }

    private func bandActions(for swatch: PaletteColor) -> some View {
        HStack(spacing: 0) {
            bandActionButton(
                copiedHex == swatch.hex ? "checkmark" : "doc.on.doc",
                emphasis: copiedHex == swatch.hex ? 0.9 : 0.42,
                label: "Copy \(swatch.hex)"
            ) { copy(swatch) }

            bandActionButton(
                swatch.isLocked ? "lock.fill" : "lock.open",
                emphasis: swatch.isLocked ? 0.9 : 0.42,
                label: swatch.isLocked ? "Unlock \(swatch.name)" : "Lock \(swatch.name)"
            ) { onToggleLock(swatch.id) }

            if palette.colors.count > PaletteStore.minimumColorCount {
                bandActionButton(
                    "trash",
                    emphasis: 0.38,
                    label: "Remove \(swatch.name)"
                ) { onDelete(swatch.id) }
            }
        }
    }

    private func bandActionButton(
        _ systemName: String,
        emphasis: Double,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .medium))
                .opacity(emphasis)
                // The symbol is visually compact, while its hit area remains a full 44 points.
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func copy(_ swatch: PaletteColor) {
        UIPasteboard.general.string = swatch.hex
        withAnimation(.easeOut(duration: 0.15)) { copiedHex = swatch.hex }
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation(.easeOut(duration: 0.2)) {
                if copiedHex == swatch.hex { copiedHex = nil }
            }
        }
    }
}

#Preview {
    PaletteBandsView(
        palette: .sample,
        onToggleLock: { _ in },
        onAddColor: { _ in },
        onDelete: { _ in },
        onOpenDetail: { _ in }
    )
}

/// Swipe a band left to remove it.
///
/// A view of its own, and that is the point rather than tidiness: the drag offset changes on every
/// frame of a gesture, and while it lived on `PaletteBandsView` each of those frames invalidated
/// the whole screen — five bands, every seam button, the type metrics — which stuttered visibly on
/// device. Held here, a drag repaints one band.
private struct SwipeToRemove<Content: View>: View {
    let width: CGFloat
    let isEnabled: Bool
    let onRemove: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var offset: CGFloat = 0

    /// How far a band must travel before releasing it removes. A third of the width: far enough
    /// that a stray horizontal drag while reaching for the lock button cannot destroy a swatch,
    /// short enough to complete comfortably with one thumb.
    private var threshold: CGFloat { width / 3 }

    /// 0...1 toward the point of no return, for the backdrop to deepen against.
    private var progress: CGFloat {
        guard threshold > 0 else { return 0 }
        return min(-offset / threshold, 1)
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Only built while a swipe is under way, so an untouched palette pays nothing for it.
            if offset < 0 {
                ZStack(alignment: .trailing) {
                    Color(.systemRed).opacity(0.35 + 0.65 * progress)
                    Image(systemName: "trash.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .scaleEffect(0.8 + 0.2 * progress)
                        .padding(.trailing, 26)
                }
            }
            content()
                .offset(x: offset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .simultaneousGesture(gesture)
    }

    /// `minimumDistance` keeps this out of the way of the tap that opens a colour's detail card,
    /// and `simultaneousGesture` at the call site stops the two competing for the touch outright.
    private var gesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { value in
                guard isEnabled else { return }
                // Leftward only. A rightward drag does nothing rather than moving the band
                // somewhere that has no meaning.
                offset = min(0, value.translation.width)
            }
            .onEnded { value in
                guard isEnabled else { return }
                if -value.translation.width > threshold {
                    // Send it the rest of the way first, so the band leaves rather than vanishing;
                    // the stack then closes the gap with the same spring the trash button uses.
                    withAnimation(ControlMotion.press) { offset = -width }
                    onRemove()
                } else {
                    withAnimation(ControlMotion.press) { offset = 0 }
                }
            }
    }
}
