import Foundation

/// Scores a palette across five dimensions. A line-for-line port of `scorePalette()` in the web
/// app's `lib/paletteHealth.ts` — see CLAUDE.md "Ported from the web app". The thresholds, the
/// weights, the rounding and the copy are all load-bearing: the same palette must score the same
/// number and read the same sentence on both products, or the two disagree in front of a user.
///
/// The contrast maths deliberately routes through `ContrastCalculator` rather than repeating the
/// WCAG formulas locally, which the web file does. Same numbers, one implementation — CLAUDE.md
/// requires every contrast decision in this app to go through that type.
enum PaletteHealth {
    struct Dimension: Equatable {
        let label: String
        let score: Int
        let detail: String
        let tip: String
    }

    enum Grade: String, Equatable {
        case a = "A", b = "B", c = "C", d = "D", f = "F"
    }

    struct Result: Equatable {
        let contrast: Dimension
        let harmony: Dimension
        let balance: Dimension
        let vibrancy: Dimension
        let completeness: Dimension
        let overall: Int
        let grade: Grade

        var dimensions: [Dimension] { [contrast, harmony, balance, vibrancy, completeness] }
    }

    static func grade(for score: Int) -> Grade {
        switch score {
        case 85...: return .a
        case 70...: return .b
        case 55...: return .c
        case 40...: return .d
        default: return .f
        }
    }

    static func score(_ colors: [PaletteColor]) -> Result {
        guard colors.count >= 2 else {
            let empty = Dimension(label: "", score: 0, detail: "Not enough colors", tip: "")
            return Result(
                contrast: empty, harmony: empty, balance: empty,
                vibrancy: empty, completeness: empty, overall: 0, grade: .f
            )
        }

        // 0...1 channels. The neighbouring `RGB255` struct is what the "channels 0...255" note in
        // ColorMath refers to; `hsl` itself takes normalised values, as every other caller does.
        let hsls = colors.map {
            ColorMath.hsl(fromRed: $0.red, green: $0.green, blue: $0.blue)
        }
        let luminances = colors.map {
            ContrastCalculator.relativeLuminance(red: $0.red, green: $0.green, blue: $0.blue)
        }

        // MARK: Contrast

        var maxContrast = 0.0
        var passAA = 0
        var totalPairs = 0
        for i in luminances.indices {
            for j in luminances.indices where j > i {
                let ratio = ContrastCalculator.ratio(
                    r1: colors[i].red, g1: colors[i].green, b1: colors[i].blue,
                    r2: colors[j].red, g2: colors[j].green, b2: colors[j].blue
                )
                maxContrast = max(maxContrast, ratio)
                if ratio >= 4.5 { passAA += 1 }
                totalPairs += 1
            }
        }
        let aaRate = Double(passAA) / Double(totalPairs)
        var contrastScore: Double
        if maxContrast >= 7 {
            contrastScore = 90 + min(10, aaRate * 10)
        } else if maxContrast >= 4.5 {
            contrastScore = 70 + (maxContrast - 4.5) / 2.5 * 20
        } else if maxContrast >= 3 {
            contrastScore = 45 + (maxContrast - 3) / 1.5 * 25
        } else {
            contrastScore = 10 + (maxContrast - 1) / 2 * 35
        }
        let contrast = Dimension(
            label: "Contrast",
            score: rounded(min(100, max(0, contrastScore))),
            detail: "Max contrast: \(oneDecimal(maxContrast)):1 · \(passAA)/\(totalPairs) pairs pass WCAG AA",
            tip: maxContrast < 4.5
                ? "Add a very light or very dark color to create usable text/background pairs."
                : maxContrast < 7
                ? "Good contrast! Add a near-black or near-white to reach AAA for small text."
                : "Excellent contrast — palette has strong text/background options."
        )

        // MARK: Harmony

        let chromatic = hsls.filter { $0.saturation > 0.12 }
        var harmonyScore = 0.0
        var harmonyDetail = ""
        var harmonyTip = ""
        if chromatic.count <= 1 {
            harmonyScore = 82
            harmonyDetail = "Monochromatic palette — single hue family"
            harmonyTip = "Monochromatic palettes are elegant. Add a subtle accent hue for more depth."
        } else {
            let hues = chromatic.map(\.hue).sorted()
            var maxGap = 0.0
            for i in 1 ..< hues.count { maxGap = max(maxGap, hues[i] - hues[i - 1]) }
            maxGap = max(maxGap, 360 - hues[hues.count - 1] + hues[0])
            let span = 360 - maxGap

            if span < 45 {
                harmonyScore = 88
                harmonyDetail = "Analogous — hues are close and cohesive"
                harmonyTip = "Great cohesion! The colors feel unified and natural together."
            } else if span >= 150, span <= 210 {
                harmonyScore = 95
                harmonyDetail = "Complementary — opposite hues create strong contrast"
                harmonyTip = "Complementary palettes are vibrant and high-impact. Well done."
            } else if span >= 100, span < 150 {
                harmonyScore = 80
                harmonyDetail = "Split-complementary — balanced tension"
                harmonyTip = "Good balance. Try nudging hues slightly for a more classic split-complementary."
            } else if span >= 210, span <= 270 {
                harmonyScore = 88
                harmonyDetail = "Triadic — three evenly spaced hues"
                harmonyTip = "Triadic palettes are dynamic and balanced. Looks intentional."
            } else {
                harmonyScore = 58
                harmonyDetail = "Hue spread: \(rounded(span))° — may feel unintentional"
                harmonyTip = "Try shifting colors toward analogous (<60° span) or complementary (~180°) for clearer harmony."
            }
        }
        let harmony = Dimension(
            label: "Harmony",
            score: rounded(harmonyScore),
            detail: harmonyDetail,
            tip: harmonyTip
        )

        // MARK: Balance

        let lightnesses = hsls.map(\.lightness)
        let hasLight = lightnesses.contains { $0 >= 0.7 }
        let hasDark = lightnesses.contains { $0 <= 0.3 }
        let hasMid = lightnesses.contains { $0 > 0.3 && $0 < 0.7 }
        let spread = (lightnesses.max() ?? 0) - (lightnesses.min() ?? 0)
        var balanceScore = 0.0
        if hasLight { balanceScore += 30 }
        if hasDark { balanceScore += 30 }
        if hasMid { balanceScore += 25 }
        if spread >= 0.5 { balanceScore += 15 } else if spread >= 0.3 { balanceScore += 8 }
        let balanceRounded = rounded(min(100, balanceScore))
        let balance = Dimension(
            label: "Balance",
            score: balanceRounded,
            detail: "Lightness range: \(rounded((lightnesses.min() ?? 0) * 100))%–\(rounded((lightnesses.max() ?? 0) * 100))%",
            tip: !hasLight
                ? "Add a near-white or very light color to give the palette breathing room."
                : !hasDark
                ? "Add a near-black or deep dark color to anchor the palette."
                : balanceRounded < 70
                ? "Colors cluster in similar lightness values. More value contrast will improve versatility."
                : "Good value range — the palette has lights, mids, and darks."
        )

        // MARK: Vibrancy

        let saturations = hsls.map(\.saturation)
        let averageSaturation = saturations.reduce(0, +) / Double(saturations.count)
        let maxSaturation = saturations.max() ?? 0
        var vibrancyScore: Double
        if maxSaturation >= 0.7 {
            vibrancyScore = 80 + Double(rounded(averageSaturation * 20))
        } else if maxSaturation >= 0.4 {
            vibrancyScore = 50 + Double(rounded(maxSaturation * 60))
        } else if maxSaturation >= 0.15 {
            vibrancyScore = 30 + Double(rounded(maxSaturation * 80))
        } else {
            vibrancyScore = Double(rounded(maxSaturation * 200))
        }
        let vibrancy = Dimension(
            label: "Vibrancy",
            score: rounded(min(100, max(0, vibrancyScore))),
            detail: "Avg saturation: \(rounded(averageSaturation * 100))% · Peak: \(rounded(maxSaturation * 100))%",
            tip: maxSaturation < 0.15
                ? "Very low saturation — the palette feels grey/washed. Boost at least one color's saturation."
                : maxSaturation < 0.4
                ? "Muted palette. Add at least one punchy, saturated accent color."
                : averageSaturation < 0.25
                ? "Good accent color, but other colors are muted. That's fine for a subtle scheme."
                : "Great vibrancy — the palette has strong, expressive colors."
        )

        // MARK: Completeness

        let hasBackground = lightnesses.contains { $0 >= 0.75 }
        let hasTextColor = lightnesses.contains { $0 <= 0.2 }
        let hasAccent = hsls.contains { $0.saturation >= 0.4 }
        var completenessScore = 0
        if hasBackground { completenessScore += 35 }
        if hasTextColor { completenessScore += 35 }
        if hasAccent { completenessScore += 30 }
        var missing: [String] = []
        if !hasBackground { missing.append("background") }
        if !hasTextColor { missing.append("text color") }
        if !hasAccent { missing.append("accent") }
        let completeness = Dimension(
            label: "Completeness",
            score: completenessScore,
            detail: missing.isEmpty
                ? "Has background, text, and accent colors"
                : "Missing: \(missing.joined(separator: ", "))",
            tip: missing.isEmpty
                ? "Complete palette — ready to use in any design system."
                : "Add a \(missing[0]) to make the palette more usable in real designs."
        )

        let overall = rounded(
            Double(contrast.score) * 0.25 +
            Double(harmony.score) * 0.2 +
            Double(balance.score) * 0.2 +
            Double(vibrancy.score) * 0.15 +
            Double(completeness.score) * 0.2
        )

        return Result(
            contrast: contrast,
            harmony: harmony,
            balance: balance,
            vibrancy: vibrancy,
            completeness: completeness,
            overall: overall,
            grade: grade(for: overall)
        )
    }

    /// JavaScript's `Math.round` rounds halves *up*, toward positive infinity — not away from
    /// zero, and not to even. Swift's default `rounded()` rounds away from zero, which differs
    /// for negatives. Every value rounded here is non-negative, but the rule is stated explicitly
    /// so a future negative term does not silently diverge from the web.
    private static func rounded(_ value: Double) -> Int {
        Int((value).rounded(.toNearestOrAwayFromZero))
    }

    /// Matches JavaScript's `toFixed(1)`.
    private static func oneDecimal(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}
