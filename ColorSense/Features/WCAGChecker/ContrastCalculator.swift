import Foundation

/// WCAG 2.x contrast ratio math (relative luminance formula from the WCAG spec).
/// Thresholds must match vault: Claude Skill.md section 11 "WCAG Contrast Ratios".
enum ContrastCalculator {
    enum Level: Equatable {
        case fail
        case aa
        case aaa
    }

    /// Relative luminance of an sRGB color, each channel 0...1.
    static func relativeLuminance(red: Double, green: Double, blue: Double) -> Double {
        func linearize(_ channel: Double) -> Double {
            channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linearize(red) + 0.7152 * linearize(green) + 0.0722 * linearize(blue)
    }

    /// Contrast ratio between two colors, always >= 1.0 and <= 21.0.
    static func ratio(
        r1: Double, g1: Double, b1: Double,
        r2: Double, g2: Double, b2: Double
    ) -> Double {
        let l1 = relativeLuminance(red: r1, green: g1, blue: b1)
        let l2 = relativeLuminance(red: r2, green: g2, blue: b2)
        let lighter = max(l1, l2)
        let darker = min(l1, l2)
        return (lighter + 0.05) / (darker + 0.05)
    }

    static func normalTextLevel(for ratio: Double) -> Level {
        if ratio >= 7.0 { return .aaa }
        if ratio >= 4.5 { return .aa }
        return .fail
    }

    static func largeTextLevel(for ratio: Double) -> Level {
        if ratio >= 4.5 { return .aaa }
        if ratio >= 3.0 { return .aa }
        return .fail
    }

    /// Non-text contrast, e.g. UI component boundaries (SC 1.4.11): passes at 3:1.
    static func nonTextPasses(_ ratio: Double) -> Bool {
        ratio >= 3.0
    }

    /// Whether white text out-contrasts black text on the given background, channels 0...1.
    /// Drives the label color on palette bands so it flips automatically per swatch.
    static func prefersLightText(onRed red: Double, green: Double, blue: Double) -> Bool {
        let againstWhite = ratio(r1: red, g1: green, b1: blue, r2: 1, g2: 1, b2: 1)
        let againstBlack = ratio(r1: red, g1: green, b1: blue, r2: 0, g2: 0, b2: 0)
        return againstWhite > againstBlack
    }

    /// The five-point plain-language grade shown on the color detail card, ported from
    /// `rateContrast()` in the web app's labColor.ts. It is a friendlier restatement of the same
    /// WCAG thresholds `normalTextLevel` uses (7.0 and 4.5), not a separate standard — keep the
    /// two in step, and keep these labels identical to the web's.
    struct Rating: Equatable {
        enum Tone: Equatable { case good, warning, bad }
        let label: String
        let tone: Tone
    }

    /// The four pass/fail checks the web app's WCAG panel shows, plus the single best grade
    /// achieved. Ported from `evaluate()` in the web's `lib/wcagContrast.ts` — same thresholds,
    /// same labels, same grade precedence — so one pairing is never graded differently across
    /// the two apps.
    struct Verdict {
        struct Check: Identifiable {
            var id: String { label }
            let label: String
            let passes: Bool
        }

        let checks: [Check]
        /// "AAA", "AA", "AA Large" or "Fail".
        let bestGrade: String
    }

    static func verdict(for ratio: Double) -> Verdict {
        let aaNormal = ratio >= 4.5
        let aaLarge = ratio >= 3.0
        let aaaNormal = ratio >= 7.0
        let aaaLarge = ratio >= 4.5

        let bestGrade: String
        if aaaNormal { bestGrade = "AAA" }
        else if aaNormal { bestGrade = "AA" }
        else if aaLarge { bestGrade = "AA Large" }
        else { bestGrade = "Fail" }

        return Verdict(
            checks: [
                .init(label: "AA · Normal text (4.5:1)", passes: aaNormal),
                .init(label: "AA · Large text (3:1)", passes: aaLarge),
                .init(label: "AAA · Normal text (7:1)", passes: aaaNormal),
                .init(label: "AAA · Large text (4.5:1)", passes: aaaLarge),
            ],
            bestGrade: bestGrade
        )
    }

    /// The nudge behind the Contrast tool's "Fix it" and the health report's auto-remap.
    ///
    /// Ported from `suggestFix()` in the web's `lib/wcagContrast.ts`. Walks `adjust`'s lightness
    /// in 0.01 steps — hue and saturation held — until it clears `target` against `anchor`,
    /// trying first the direction that moves *away* from the anchor's luminance. Returns nil when
    /// even pure black or white cannot reach the target, which is a real outcome rather than a
    /// failure: some anchors simply have no passing partner at that hue.
    ///
    /// Each candidate is quantised to 8 bits before its ratio is measured, because the web builds
    /// a hex string at every step and measures that. Skipping the quantisation would drift from
    /// the web by a step or two near the boundary.
    static func suggestFix(
        adjust: PaletteColor,
        anchor: PaletteColor,
        target: Double
    ) -> (swatch: PaletteColor, ratio: Double, wentLighter: Bool)? {
        let anchorLuminance = relativeLuminance(red: anchor.red, green: anchor.green, blue: anchor.blue)
        let start = ColorMath.hsl(fromRed: adjust.red, green: adjust.green, blue: adjust.blue)

        func walk(lighter: Bool) -> (swatch: PaletteColor, ratio: Double, wentLighter: Bool)? {
            let step = 0.01
            var lightness = start.lightness
            // 101 steps covers the whole 0...1 range from any starting point.
            for _ in 0 ..< 101 {
                lightness += lighter ? step : -step
                let clamped = min(max(lightness, 0), 1)
                let rgb = ColorMath.rgb(
                    from: .init(hue: start.hue, saturation: start.saturation, lightness: clamped)
                )
                let candidate = PaletteColor(
                    red: quantised(rgb.red),
                    green: quantised(rgb.green),
                    blue: quantised(rgb.blue),
                    dominance: adjust.dominance
                )
                let ratio = self.ratio(
                    r1: candidate.red, g1: candidate.green, b1: candidate.blue,
                    r2: anchor.red, g2: anchor.green, b2: anchor.blue
                )
                if ratio >= target { return (candidate, ratio, lighter) }
                if clamped == 0 || clamped == 1 { return nil }
            }
            return nil
        }

        let preferLighter = anchorLuminance < 0.5
        return walk(lighter: preferLighter) ?? walk(lighter: !preferLighter)
    }

    private static func quantised(_ channel: Double) -> Double {
        (min(max(channel, 0), 1) * 255).rounded() / 255
    }

    static func rating(for ratio: Double) -> Rating {
        if ratio >= 7.0 { return Rating(label: "GREAT 5/5", tone: .good) }
        if ratio >= 4.5 { return Rating(label: "GOOD 4/5", tone: .good) }
        if ratio >= 3.0 { return Rating(label: "OK 3/5", tone: .warning) }
        if ratio >= 2.0 { return Rating(label: "POOR 2/5", tone: .bad) }
        return Rating(label: "POOR 1/5", tone: .bad)
    }
}
