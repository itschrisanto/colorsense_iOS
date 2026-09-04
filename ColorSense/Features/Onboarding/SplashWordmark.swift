import SwiftUI

/// The wordmark and its loading bar, at the foot of the splash beat.
///
/// **The word is black and the colour lives in the bar.** Every brand ink was measured on CORAL
/// through `ContrastCalculator` before this was built: black is 7.57:1, white 2.78:1, YELLOW
/// 2.01:1, PURPLE 1.44:1 and TEAL 1.43:1. Black is the only one that passes, and it is not close,
/// so a rainbow wordmark would have had letters the app's own checker rates POOR 1/5 on the first
/// screen anybody sees. The bar carries the palette instead, at full saturation, because it holds
/// no words and does not have to be legible. Same reasoning as the bands themselves: full-bleed
/// colour with measured type on top, and exactly one thing asking to be read.
///
/// **Nothing here is loading.** The splash is a five-second hold, not a wait on work, so this is a
/// brand device rather than a progress claim, and it deliberately has no percentage, no track that
/// fills to completion, and no end state.
///
/// **It is a pure function of the clock, and holds no state.** This screen has already cost this
/// project the same bug twice, recorded in CLAUDE.md: a `.task` chain driving frames is tied to
/// view lifetime, an early rebuild cancels it, `try? await` swallows the cancellation, and the
/// sequence silently restarts. Launch is exactly when those rebuilds happen, and the simulator is
/// idle enough to hide it. A `TimelineView` over `Date` cannot restart, stall, or desynchronise,
/// because there is nothing to reset.
struct SplashWordmark: View {
    /// Measured against the band this sits on, never assumed. On CORAL this resolves to black.
    let ink: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// **The wordmark does not scale with Dynamic Type, deliberately.** It is a logo, not copy: it
    /// carries no information a reader has to be able to enlarge, and its accessibility label
    /// already says "ColorSense". Scaled, it was a disaster — at accessibility-extra-extra-extra-
    /// large the name filled the screen edge to edge, the bar ran the full width with it, and
    /// Lauma was pushed off the top of the display. Same reasoning as the dock and strip glyphs.
    ///
    /// A constant is not enough on its own: `BrandFont.ui` scales whatever size it is given,
    /// because `Font.custom(_:size:)` does. `BrandFont.uiFixed` is the non-scaling form.
    private static let wordSize: CGFloat = 32

    /// One pass of the bar. Slow enough to read as a deliberate sweep rather than a spinner, and
    /// short enough that three land inside the five-second hold.
    private static let cycle: Double = 1.7
    private static let trackHeight: CGFloat = 5
    /// The travelling segment, as a fraction of the track.
    private static let segmentFraction: CGFloat = 0.5

    /// All four brand colours, so the bar is the product's own palette rather than a tinted rule.
    /// CORAL is in it deliberately: the segment sits on a darkened track, so it reads there even
    /// though the field behind the whole screen is also CORAL.
    private var sweep: LinearGradient {
        LinearGradient(
            colors: [BrandColor.coral, BrandColor.yellow, BrandColor.teal, BrandColor.purple],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        // The bar takes the wordmark's width at any text size, with no measurement and no state:
        // `fixedSize` proposes nothing horizontally, so the stack adopts the type's ideal width and
        // the bar's `maxWidth: .infinity` then fills exactly that. A fixed number would be wider
        // than the word at one Dynamic Type size and narrower at the next.
        VStack(spacing: 14) {
            // **DM Sans, not the Bebas display face.** The brand is *ColorSense*, and Bebas Neue
            // is caps-only, so it would render the wordmark as COLORSENSE and destroy the casing
            // the name is written in. This is the same trap the `hello` beat's speech bubble
            // records: reaching for the display face is right for a headline set in caps and wrong
            // for anything whose casing carries meaning. The brand name is one of those.
            Text("ColorSense")
                .font(BrandFont.uiFixed(Self.wordSize, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(ink)
                .accessibilityAddTraits(.isHeader)

            bar
                .accessibilityHidden(true)
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("ColorSense")
    }

    private var bar: some View {
        // Reduce Motion gets the whole palette at rest rather than a band travelling across the
        // screen. This is motion through space, which is what the setting is for — unlike the
        // blink above it, where an eyelid moves nothing and the animation deliberately continues.
        Group {
            if reduceMotion {
                Capsule().fill(sweep)
            } else {
                GeometryReader { geo in
                    TimelineView(.animation) { context in
                        let elapsed = context.date.timeIntervalSinceReferenceDate
                        let phase = elapsed.truncatingRemainder(dividingBy: Self.cycle) / Self.cycle
                        movingSegment(phase: phase, across: geo.size.width)
                    }
                }
            }
        }
        .frame(height: Self.trackHeight)
        .frame(maxWidth: .infinity)
        .background(Capsule().fill(ink.opacity(0.22)))
        .clipShape(Capsule())
    }

    private func movingSegment(phase: Double, across width: CGFloat) -> some View {
        let segment = width * Self.segmentFraction
        // Travels from fully off the leading edge to fully off the trailing one, so the loop has
        // no visible jump at the wrap.
        let travel = width + segment
        let x = -segment + travel * CGFloat(phase)
        return Capsule()
            .fill(sweep)
            .frame(width: segment, height: Self.trackHeight)
            .offset(x: x)
            .frame(width: width, height: Self.trackHeight, alignment: .leading)
    }
}

#Preview {
    ZStack {
        BrandColor.coral.ignoresSafeArea()
        SplashWordmark(ink: PaletteColor(color: BrandColor.coral).legibleForeground)
    }
}
