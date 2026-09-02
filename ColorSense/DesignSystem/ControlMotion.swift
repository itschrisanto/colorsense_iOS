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
