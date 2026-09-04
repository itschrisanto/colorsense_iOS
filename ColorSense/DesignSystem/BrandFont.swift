import SwiftUI

/// Display font is Bebas Neue, UI font is DM Sans (vault: Claude Skill.md section 8).
/// The four `.ttf` faces live in `Resources/Fonts/` and are declared in `project.yml` under
/// `UIAppFonts` — see CLAUDE.md "Fonts" for the traps if they are ever replaced. A missing or
/// misnamed face never crashes; it silently renders as the system font.
///
/// Everything here responds to Dynamic Type. `Font.custom(_:size:)` scales relative to `.body`
/// on its own (the *non*-scaling form is `custom(_:fixedSize:)`), so `display` and `ui` need
/// nothing special — but system fonts have no `relativeTo:` equivalent, which is why `mono` is
/// a view modifier rather than a `Font`. See `brandMono(_:weight:)` below.
enum BrandFont {
    static func display(_ size: CGFloat) -> Font {
        .custom("BebasNeue-Regular", size: size, relativeTo: .largeTitle)
    }

    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(faceName(for: weight), size: size)
    }

    /// The UI face at a size Dynamic Type does not touch.
    ///
    /// `Font.custom(_:size:)` scales on its own, which is right for every piece of copy and wrong
    /// for the few things that are pictures rather than words. The splash wordmark is the case
    /// that forced this: scaled, at accessibility-extra-extra-extra-large it ran off both edges of
    /// the screen and pushed the mascot off the top. A logo carries no information a reader needs
    /// to enlarge, and it has an accessibility label that VoiceOver reads at any size.
    ///
    /// **Use this only for marks and glyph-like text.** Anything somebody has to read takes `ui`.
    static func uiFixed(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(faceName(for: weight), fixedSize: size)
    }

    private static func faceName(for weight: Font.Weight) -> String {
        switch weight {
        case .bold, .heavy, .black: return "DMSans-Bold"
        case .medium, .semibold: return "DMSans-Medium"
        default: return "DMSans-Regular"
        }
    }
}

/// Hex codes, contrast ratios and LAB/HSL values are set in a monospaced face so digits align
/// down a stack of palette bands, matching the web app. There is no brand mono, so this is the
/// system monospace on purpose.
///
/// It is a `ViewModifier` and not a `Font`-returning function because `Font.system(size:)` is
/// fixed — it has no Dynamic Type response, and unlike `Font.custom` there is no `relativeTo:`
/// form for system fonts. Left as a plain `Font`, hex codes stayed pixel-identical while every
/// name around them grew, so a reader who had turned text size up got a larger label and an
/// unreadable value — backwards, since the value is the data.
///
/// `@ScaledMetric` supplies the multiplier and, just as importantly, creates the environment
/// dependency that makes SwiftUI re-render when the reader changes their text size mid-session.
/// A static function reading `UIFontMetrics` would compute the right number once and then go
/// stale, because nothing would tell SwiftUI to run the body again.
private struct ScaledMono: ViewModifier {
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1
    let size: CGFloat
    let weight: Font.Weight

    func body(content: Content) -> some View {
        content.font(.system(size: size * scale, weight: weight, design: .monospaced))
    }
}

extension View {
    /// Applies the monospaced value face at `size`, scaled for the reader's text size.
    func brandMono(_ size: CGFloat, weight: Font.Weight = .bold) -> some View {
        modifier(ScaledMono(size: size, weight: weight))
    }
}
