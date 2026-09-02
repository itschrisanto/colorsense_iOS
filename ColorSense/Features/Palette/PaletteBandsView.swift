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
    let onMove: (Int, Int) -> Void

    /// Hex of the swatch most recently copied, so its button can confirm with a checkmark.
    @State private var copiedHex: String?
    /// One counter per seam, so spinning one + does not spin the others.
    @State private var seamTaps: [Int: Int] = [:]
    /// Bumped on a completed swipe, purely to fire a haptic.
    @State private var swipeDeletes = 0
    /// Band width, for the swipe threshold. Read from a background reader rather than wrapping
    /// the stack in a GeometryReader, which would change how the bands are laid out.
    @State private var bandWidth: CGFloat = 0
    @State private var bandsHeight: CGFloat = 0
    /// Which band is being carried, and the slot it would land in. Set only when the slot
    /// changes rather than on every frame of the drag — the frame-by-frame movement is local to
    /// the band, which is what keeps a drag from repainting the whole screen.
    @State private var draggingIndex: Int?
    @State private var dropIndex: Int?
    @State private var reorders = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ForEach(Array(palette.colors.enumerated()), id: \.element.id) { index, swatch in
                    band(swatch, index: index, width: bandWidth)
                        // A sibling being carried past this one opens a gap. Only the bands
                        // between the source and the destination move, and only by one slot.
                        .offset(y: gapOffset(for: index))
                        .zIndex(draggingIndex == index ? 1 : 0)
                }
            }

            if palette.colors.count < PaletteStore.maximumColorCount, draggingIndex == nil {
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
                    .onAppear {
                        bandWidth = proxy.size.width
                        bandsHeight = proxy.size.height
                    }
                    .onChange(of: proxy.size.width) { _, width in bandWidth = width }
                    .onChange(of: proxy.size.height) { _, height in bandsHeight = height }
            }
        }
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: swipeDeletes)
        // A lighter tick than a removal: passing a slot is a step, not a commitment.
        .sensoryFeedback(.selection, trigger: dropIndex)
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

    /// Height of one band, for turning a vertical drag into a number of slots.
    private var bandHeight: CGFloat {
        bandsHeight / CGFloat(max(palette.colors.count, 1))
    }

    /// How far a band that is *not* being carried should step aside.
    private func gapOffset(for index: Int) -> CGFloat {
        guard let from = draggingIndex, let to = dropIndex, from != to, index != from else { return 0 }
        if from < to {
            return (index > from && index <= to) ? -bandHeight : 0
        } else {
            return (index >= to && index < from) ? bandHeight : 0
        }
    }

    private func band(_ swatch: PaletteColor, index: Int, width: CGFloat) -> some View {
        BandDrag(
            index: index,
            slotCount: palette.colors.count,
            bandHeight: bandHeight,
            width: width,
            canRemove: canRemove,
            canReorder: palette.colors.count > 1,
            onRemove: {
                swipeDeletes += 1
                onDelete(swatch.id)
            },
            onSlot: { from, to in
                draggingIndex = from
                dropIndex = to
            },
            onDrop: { from, to in
                draggingIndex = nil
                dropIndex = nil
                guard from != to else { return }
                reorders += 1
                withAnimation(PaletteMotion.structural(reduceMotion: reduceMotion)) {
                    onMove(from, to)
                }
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
        AnalyticsService.capture(.colorCopied, ["from": "band"])
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
        onOpenDetail: { _ in },
        onMove: { _, _ in }
    )
}

/// Both of a band's drags, resolved by one gesture rather than two competing ones.
///
/// A horizontal drag removes; a vertical drag reorders. They cannot be separate recognisers —
/// each would try to claim the touch and a diagonal start would fire whichever won — so the axis
/// is decided once, on the first movement past the threshold, and held for the rest of the
/// gesture. A drag that starts sideways stays a removal even if it wanders downward.
///
/// The frame-by-frame movement is held here rather than by the parent, and that placement is the
/// difference between smooth and stuttering: while it lived on `PaletteBandsView` every frame of
/// a drag invalidated the whole screen. The parent hears only when the *slot* changes, which is a
/// handful of times per drag instead of sixty a second.
private struct BandDrag<Content: View>: View {
    let index: Int
    let slotCount: Int
    let bandHeight: CGFloat
    let width: CGFloat
    let canRemove: Bool
    let canReorder: Bool
    let onRemove: () -> Void
    let onSlot: (Int, Int) -> Void
    let onDrop: (Int, Int) -> Void
    @ViewBuilder let content: () -> Content

    private enum Axis { case horizontal, vertical }

    @State private var axis: Axis?
    @State private var dx: CGFloat = 0
    @State private var dy: CGFloat = 0
    @State private var slot: Int?

    /// A third of the width to remove: far enough that a stray sideways drag while reaching for
    /// the lock button cannot destroy a swatch, short enough for one thumb.
    private var removeThreshold: CGFloat { width / 3 }

    private var progress: CGFloat {
        guard removeThreshold > 0 else { return 0 }
        return min(-dx / removeThreshold, 1)
    }

    private var isCarrying: Bool { axis == .vertical }

    var body: some View {
        ZStack(alignment: .trailing) {
            if dx < 0 {
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
                .offset(x: dx, y: dy)
                // Lifted while carried, so it reads as picked up rather than merely misaligned.
                .scaleEffect(isCarrying ? 0.97 : 1)
                .shadow(color: .black.opacity(isCarrying ? 0.28 : 0), radius: 14, y: 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .simultaneousGesture(gesture)
    }

    private var gesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { value in
                if axis == nil {
                    let horizontal = abs(value.translation.width) > abs(value.translation.height)
                    if horizontal, canRemove { axis = .horizontal }
                    else if !horizontal, canReorder { axis = .vertical }
                    else { return }
                }

                switch axis {
                case .horizontal:
                    // Leftward only. A rightward drag does nothing rather than moving the band
                    // somewhere that has no meaning.
                    dx = min(0, value.translation.width)
                case .vertical:
                    dy = value.translation.height
                    guard bandHeight > 0 else { return }
                    let steps = Int((dy / bandHeight).rounded())
                    let target = min(max(index + steps, 0), slotCount - 1)
                    if target != slot {
                        slot = target
                        onSlot(index, target)
                    }
                case nil:
                    break
                }
            }
            .onEnded { value in
                switch axis {
                case .horizontal:
                    if -value.translation.width > removeThreshold {
                        withAnimation(ControlMotion.press) { dx = -width }
                        onRemove()
                    } else {
                        withAnimation(ControlMotion.press) { dx = 0 }
                    }
                case .vertical:
                    // The offset is dropped without animation because the parent is about to
                    // reorder the array: animating it home would slide the band back to where it
                    // came from and then have it jump to its new slot.
                    let target = slot ?? index
                    dy = 0
                    onDrop(index, target)
                case nil:
                    break
                }
                axis = nil
                slot = nil
            }
    }
}
