import SwiftUI

/// The floating glass bar the app is navigated from.
///
/// There are two of them — the palette dock in `RootView` and the tool strip in the workspace —
/// and they are the same object rather than two things that resemble each other. Bars in the same
/// position that look like different species is worse than either alone, so the capsule, the
/// hairline, the shadow, the insets, the glyph size and the press feedback all live here and are
/// used by both. What legitimately differs between them is the ink, and only the ink: the dock
/// floats on the palette and measures itself against the swatch underneath, while the strip floats
/// on panel content and has no swatch to measure.
extension View {
    /// Glass, hairline, shadow, and the 20pt inset that makes it read as floating over the screen
    /// rather than as a slab bolted to the bottom of it.
    func dockCapsule(foreground: Color) -> some View {
        self
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay { Capsule().strokeBorder(foreground.opacity(0.14), lineWidth: 0.5) }
            .shadow(color: .black.opacity(0.2), radius: 14, y: 5)
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .frame(maxWidth: .infinity)
    }
}

/// Dock glyphs at a common point size.
///
/// A view rather than a method on the containing screen so it can be built inside `Button` label
/// closures, which are not main-actor isolated.
struct DockIcon: View {
    let systemName: String
    var size: CGFloat = 21
    /// Residual correction for symbols whose *ink* sits off-centre inside their own layout box,
    /// which a common point size cannot fix. Measure it from a screenshot rather than eyeballing:
    /// crop the dock, threshold the dark pixels, and compare each glyph's bounding-box centre.
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

/// One icon-only item in a dock capsule.
///
/// The glyph carries no visible caption, so `label` is what VoiceOver reads and is not optional.
/// Selection, where a bar has such a thing, is expressed by the `foreground` the caller passes
/// rather than by anything here: the strip dims its unselected items, and the dock, whose items
/// are all actions, never dims anything.
struct DockButton: View {
    let systemName: String
    let label: String
    let foreground: Color
    var size: CGFloat = 21
    var opticalOffset: CGFloat = 0
    let action: () -> Void

    init(
        _ systemName: String,
        label: String,
        foreground: Color,
        size: CGFloat = 21,
        opticalOffset: CGFloat = 0,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.label = label
        self.foreground = foreground
        self.size = size
        self.opticalOffset = opticalOffset
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            DockIcon(systemName, size: size, opticalOffset: opticalOffset)
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
