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
