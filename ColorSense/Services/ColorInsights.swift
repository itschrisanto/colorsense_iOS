import Foundation

/// The Psychology / Meaning / Applications copy shown on the color detail card.
///
/// This is brand copy, transcribed verbatim from the web app's `colorInsights()` in
/// `artifacts/color-palette/src/lib/labColor.ts`, along with its exact hue boundaries. Do not
/// reword it here and do not write new entries from scratch — the vault owns ColorSense's voice,
/// and the same hex must say the same thing on iOS as it does on colorsense.online. If this copy
/// needs to change, change it on the web first and re-port.
///
/// It is a local heuristic on purpose: free for everyone, no AI call, no network.
struct ColorInsight {
    let psychology: String
    let meaning: String
    let applications: String
}

enum ColorInsights {
    private static let neutralLight = ColorInsight(
        psychology: "Soft, near-white tones feel clean, open and calm, giving the eye room to rest.",
        meaning: "Reads as simplicity, clarity and space — modern, honest and unfussy.",
        applications: "Best as a background or negative space that lets brighter colors breathe."
    )
    private static let neutralMid = ColorInsight(
        psychology: "Mid greys feel neutral, practical and composed — quiet and dependable.",
        meaning: "Signals balance, professionalism and restraint without taking a side.",
        applications: "Useful for borders, secondary text, dividers and understated UI surfaces."
    )
    private static let neutralDark = ColorInsight(
        psychology: "Deep near-black tones read as serious, premium and grounded.",
        meaning: "Conveys authority, sophistication and focus — a strong anchor.",
        applications: "Ideal for body text, headers and high-contrast backgrounds."
    )

    private struct Family {
        /// Half-open hue range in degrees. Reds wrap past 360, expressed as `lowerBound`
        /// greater than `upperBound` — the web writes this as `h < 15 || h >= 345`.
        let lowerBound: Double
        let upperBound: Double
        let insight: ColorInsight

        func contains(_ hue: Double) -> Bool {
            lowerBound > upperBound
                ? (hue >= lowerBound || hue < upperBound)
                : (hue >= lowerBound && hue < upperBound)
        }
    }

    /// Hue families, in the web's order, covering 0..<360 once the red wrap-around is applied.
    private static let families: [Family] = [
        Family(lowerBound: 345, upperBound: 15, insight: ColorInsight(
            psychology: "Reds are energising and attention-grabbing, raising urgency, appetite and passion.",
            meaning: "Signals power, excitement and boldness — confident and impossible to ignore.",
            applications: "Great for primary buttons, sale tags and accents that must be noticed."
        )),
        Family(lowerBound: 15, upperBound: 45, insight: ColorInsight(
            psychology: "Warm oranges radiate friendliness, optimism and approachable, playful energy.",
            meaning: "Evokes warmth, creativity and enthusiasm — inviting without being aggressive.",
            applications: "Works for highlights, calls to action and food, lifestyle or community brands."
        )),
        Family(lowerBound: 45, upperBound: 65, insight: ColorInsight(
            psychology: "Yellows feel cheerful and stimulating, linked to sunlight, clarity and happiness.",
            meaning: "Suggests optimism, energy and intellect — bright and forward-looking.",
            applications: "Good for highlights and badges; pair with dark text for readability."
        )),
        Family(lowerBound: 65, upperBound: 160, insight: ColorInsight(
            psychology: "Greens feel calm and restorative, tied to growth, health and steady progress.",
            meaning: "Signals renewal, nature and sustainability — reassuring and balanced.",
            applications: "Great for confirmations, wellness or eco brands, and 'go' accents."
        )),
        Family(lowerBound: 160, upperBound: 200, insight: ColorInsight(
            psychology: "Teals and cyans feel fresh, clear and modern — calming yet quietly confident.",
            meaning: "Conveys clarity, communication and innovation with a clean edge.",
            applications: "Suits tech, healthcare and SaaS UI, links and informational accents."
        )),
        Family(lowerBound: 200, upperBound: 250, insight: ColorInsight(
            psychology: "Blues read as stable, focused and trustworthy — the color of quiet authority.",
            meaning: "Signals professionalism, depth and reliability; a dependable anchor.",
            applications: "Ideal for headers, primary brand color and trust-building surfaces."
        )),
        Family(lowerBound: 250, upperBound: 290, insight: ColorInsight(
            psychology: "Purples feel imaginative and premium, blending calm blue with creative red.",
            meaning: "Evokes luxury, creativity and ambition — distinctive and a little magical.",
            applications: "Great for creative, beauty or premium brands and standout accents."
        )),
        Family(lowerBound: 290, upperBound: 345, insight: ColorInsight(
            psychology: "Pinks and magentas feel warm, expressive and contemporary — bold but friendly.",
            meaning: "Signals energy, playfulness and modern confidence with a youthful edge.",
            applications: "Works for vibrant CTAs, creative brands and standout highlights."
        )),
    ]

    static func insight(for swatch: PaletteColor) -> ColorInsight {
        let hsl = ColorMath.hsl(fromRed: swatch.red, green: swatch.green, blue: swatch.blue)

        // Desaturated colors have no meaningful hue family — they're read by lightness instead.
        if hsl.saturation < 0.12 {
            if hsl.lightness >= 0.8 { return neutralLight }
            if hsl.lightness <= 0.25 { return neutralDark }
            return neutralMid
        }
        return families.first { $0.contains(hsl.hue) }?.insight ?? neutralMid
    }
}
