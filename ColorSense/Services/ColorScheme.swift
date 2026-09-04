import Foundation

/// The Color Scheme Generator, ported from `getHarmonyColors()` in the web's
/// `components/lab/panels/SchemePanel.tsx`.
///
/// **This is not `ColorHarmony`, and the two must not be merged.** That one ports `harmoniesFor()`
/// in `labColor.ts` and is what the swatch detail screen shows. They disagree on purpose, because
/// the web has both and they are different features:
///
/// - `ColorHarmony` guards near-greys (saturation below 0.05 becomes s 0.6, l 0.55) and clamps
///   every rotated lightness to 0.12...0.88. This one does neither, so a grey base here yields
///   greys, which is the honest answer when somebody has *picked* grey on a colour wheel.
/// - This one returns the base colour untouched as the first entry of most schemes, rather than
///   recomputing it through HSL.
/// - This one has `tetradic`, which the other has not, and its `monochromatic` is five lightness
///   steps rather than a hue rotation.
///
/// Keep it in step with the web panel, not with `ColorHarmony`.
enum ColorScheme {
    enum Harmony: String, CaseIterable, Identifiable {
        case complementary
        case monochromatic
        case analogous
        case splitComplementary
        case triadic
        case tetradic

        var id: String { rawValue }

        /// The web abbreviates split-complementary to "Split-comp." to fit a narrow column. A
        /// scrolling chip row has no such constraint, and `ColorDetailView` already writes it in
        /// full, so iOS is internally consistent instead.
        var title: String {
            switch self {
            case .complementary: return "Complementary"
            case .monochromatic: return "Monochromatic"
            case .analogous: return "Analogous"
            case .splitComplementary: return "Split Complementary"
            case .triadic: return "Triadic"
            case .tetradic: return "Tetradic"
            }
        }

        var summary: String {
            switch self {
            case .complementary: return "Opposite on the wheel. High contrast."
            case .monochromatic: return "One hue, five lightnesses."
            case .analogous: return "Neighbors. Calm and cohesive."
            case .splitComplementary: return "Contrast, with less tension."
            case .triadic: return "Evenly spaced. Vivid and balanced."
            case .tetradic: return "Two complementary pairs."
            }
        }
    }

    /// Every scheme for a base color, in the web's order and with its exact arithmetic.
    static func colors(base: PaletteColor, harmony: Harmony) -> [PaletteColor] {
        let hsl = ColorMath.hsl(fromRed: base.red, green: base.green, blue: base.blue)
        let h = hsl.hue, s = hsl.saturation, l = hsl.lightness

        func at(_ hue: Double, _ saturation: Double, _ lightness: Double) -> PaletteColor {
            let rgb = ColorMath.rgb(from: .init(hue: hue, saturation: saturation, lightness: lightness))
            return PaletteColor(red: rgb.red, green: rgb.green, blue: rgb.blue, dominance: 0)
        }

        switch harmony {
        case .complementary:
            return [base, at(h + 180, s, l)]
        case .monochromatic:
            // Note the middle step is recomputed through HSL rather than being `base` itself, which
            // is what the web does and can differ from the base by a rounding step.
            let steps = [
                max(0.15, l - 0.3), max(0.25, l - 0.15), l,
                min(0.75, l + 0.15), min(0.9, l + 0.3),
            ]
            return steps.map { at(h, s, $0) }
        case .analogous:
            return [at(h - 30, s, l), base, at(h + 30, s, l)]
        case .splitComplementary:
            return [base, at(h + 150, s, l), at(h + 210, s, l)]
        case .triadic:
            return [base, at(h + 120, s, l), at(h + 240, s, l)]
        case .tetradic:
            return [base, at(h + 90, s, l), at(h + 180, s, l), at(h + 270, s, l)]
        }
    }

    /// The panel's Randomize, with the web's ranges: any hue, saturation 0.55 to 0.90, lightness
    /// 0.40 to 0.65. Deliberately never near-grey and never near-black or near-white, so the wheel
    /// always lands somewhere a scheme can be built from.
    static func randomBase() -> PaletteColor {
        let rgb = ColorMath.rgb(from: .init(
            hue: Double.random(in: 0..<360),
            saturation: 0.55 + Double.random(in: 0..<0.35),
            lightness: 0.4 + Double.random(in: 0..<0.25)
        ))
        return PaletteColor(red: rgb.red, green: rgb.green, blue: rgb.blue, dominance: 0)
    }

    /// Where a color sits on the wheel: hue as an angle with 0 at the top, saturation as distance
    /// from the centre. Lightness is not represented, which is why picking from the wheel always
    /// commits at lightness 0.5, exactly as the web panel does.
    static func wheelPosition(of swatch: PaletteColor) -> (angle: Double, radius: Double) {
        let hsl = ColorMath.hsl(fromRed: swatch.red, green: swatch.green, blue: swatch.blue)
        return (angle: hsl.hue - 90, radius: min(hsl.saturation, 1))
    }

    /// The inverse: a point on the wheel becomes a color. Saturation has a floor of 0.05 so the
    /// exact centre still yields something with a hue to build a scheme from.
    static func color(atAngle degrees: Double, radius: Double) -> PaletteColor {
        let hue = (degrees + 90).truncatingRemainder(dividingBy: 360)
        let rgb = ColorMath.rgb(from: .init(
            hue: hue < 0 ? hue + 360 : hue,
            saturation: max(0.05, min(radius, 1)),
            lightness: 0.5
        ))
        return PaletteColor(red: rgb.red, green: rgb.green, blue: rgb.blue, dominance: 0)
    }
}
