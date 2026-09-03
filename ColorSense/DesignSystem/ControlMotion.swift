import SwiftUI

/// How controls respond to being touched, as distinct from `PaletteMotion`, which is how the
/// palette responds to being changed.
enum ControlMotion {
    /// The quarter turn both `+` buttons make when tapped.
    ///
    /// Ninety degrees specifically, because a plus has four-fold symmetry and therefore lands
    /// looking exactly as it started. The spin is visible in flight while implying no change of
    /// state — which is the point, since both buttons *open* something. Forty-five degrees would
    /// turn the glyph into a ×, which reads as "close" and would be a lie.
    static func spin(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.6)
    }

    /// The press-down spring shared by the dock's items.
    static let press = Animation.spring(response: 0.28, dampingFraction: 0.7)
}

/// Onboarding is the one place where character movement carries meaning: Lauma arrives, reacts
/// and points, and the palette blooms in behind her. Every curve here returns nil under Reduce
/// Motion, so the flow still reads correctly as a sequence of still frames.
enum OnboardingMotion {

    /// Moving between beats of the flow. Damped almost to critical on purpose: a page sliding
    /// across should settle, not bounce, and at 0.85 the overshoot was visible on the headline.
    static func beat(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.96)
    }



    /// How one beat's content is replaced by the next: the old page leaves to the left as the new
    /// one arrives from the right.
    ///
    /// Two earlier attempts are worth not repeating. Originally there was **no** transition at all,
    /// because a `switch` swaps the subtree in a single frame, so the words and Lauma cut instantly
    /// while the band colours and strip heights were still springing to their new values. Replacing
    /// that with a fade-through fixed the mismatch but was still not smooth: content vanishing in
    /// place and reappearing in place reads as a blink, and a straight cross-fade is worse, because
    /// almost every beat has Lauma in it and two half-transparent Laumas overlap into a smear.
    ///
    /// A slide solves the ghosting by construction rather than by timing it around: the two Laumas
    /// are never in the same place, so they can share the screen while one leaves. It also matches
    /// what the flow actually is, a sequence of pages moving forward, so the motion carries meaning
    /// instead of just covering a swap. The flow only ever advances, which is why this is one
    /// direction and not a pair.
    ///
    /// The bands underneath deliberately do not participate. They morph continuously through the
    /// whole thing, so the colour field stays put as a stage while the content travels across it,
    /// which is what makes `mood` look like the field splitting rather than cutting.
    static func beatContent(reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else { return .identity }
        return .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
}

/// Press feedback for the two `+` buttons.
///
/// They previously used `.buttonStyle(.plain)`, which gave them no press response at all — so the
/// coral `+`, the single focal point of an otherwise icon-only dock, was the one control in it
/// that did not react to touch. `.plain` is still what keeps a button's tint from repainting the
/// glyph system-blue; this adds back the feedback that came with it.
struct PlusButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .animation(ControlMotion.press, value: configuration.isPressed)
    }
}
