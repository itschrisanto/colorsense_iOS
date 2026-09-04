import SwiftUI

/// The app's primary action button: full width, coral, white label.
///
/// `SavePaletteView` and `ColorDetailView` had already settled on this shape and spelled it out
/// identically in both places. SVG Recolor then arrived using `.borderedProminent` with a coral
/// tint, which is the *system* button: different padding, a different corner radius, a different
/// label font and a different label colour. Two houses styles is one too many, so this is the
/// existing one, named, and every primary action now uses it.
///
/// Note the label colour is **white by house style, not by measurement**. `legibleForeground`
/// picks black on CORAL, and these buttons deliberately do not follow it. See CLAUDE.md.
struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BrandFont.ui(15, weight: .medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(BrandColor.coral, in: RoundedRectangle(cornerRadius: 13))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

extension ButtonStyle where Self == PrimaryActionButtonStyle {
    static var primaryAction: PrimaryActionButtonStyle { PrimaryActionButtonStyle() }
}

/// The secondary action: same shape and target as the primary, drawn as an outline.
///
/// Exists because Visualizer's Shuffle and Improve were toolbar-sized text buttons in a header row,
/// which is a small target for a thumb and read as chrome rather than as the two things you are
/// most likely to press. They are full-width buttons under the swatches now, and this is what makes
/// them look like buttons without competing with a primary action they sit beside.
struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BrandFont.ui(15, weight: .medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .foregroundStyle(Color.primary)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 13))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension ButtonStyle where Self == SecondaryActionButtonStyle {
    static var secondaryAction: SecondaryActionButtonStyle { SecondaryActionButtonStyle() }
}
