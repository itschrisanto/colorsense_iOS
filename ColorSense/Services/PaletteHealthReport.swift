import Foundation

/// The client-ready Palette Health report, ported from `buildHealthReportData()` in the web app's
/// `lib/paletteHealthReport.ts`.
///
/// Everything here is measured or derived from the palette — never hardcoded, and never estimated
/// without saying so. That is the web file's own stated rule and it is the reason the report is
/// worth handing to a client at all.
///
/// One deliberate divergence, recorded in CLAUDE.md: the web's fix copy tells the reader to use
/// the Lab's one-click auto-remap. That is a Pro feature of the web app and has no iOS equivalent
/// yet, so pointing at it here would be an instruction a reader cannot follow. The iOS wording
/// points at the swatch editor this app does have. Everything else is verbatim.
struct PaletteHealthReport {
    struct ContrastRow: Identifiable, Equatable {
        enum Tone: Equatable { case pass, warn, fail }

        var id: Int { backgroundIndex }
        let foreground: PaletteColor
        let background: PaletteColor
        let backgroundName: String
        let backgroundIndex: Int
        let ratio: Double
        let ratioText: String
        let verdict: String
        let tone: Tone
    }

    struct Entry: Identifiable, Equatable {
        var id: Int { index }
        let index: Int
        let swatch: PaletteColor
        let role: String
        let cmyk: String
    }

    struct Fix: Identifiable, Equatable {
        var id: String { title }
        let title: String
        let body: String
    }

    let paletteName: String
    let preparedDate: String
    let health: PaletteHealth.Result
    let entries: [Entry]
    let summary: String
    let issueCount: Int
    let contrastRows: [ContrastRow]
    let colorBlindKind: ColorBlindness.Kind
    let simulated: [PaletteColor]
    let colorBlindFinding: String
    let fixes: [Fix]

    // MARK: - Building

    static func build(
        for colors: [PaletteColor],
        name: String,
        seenAs kind: ColorBlindness.Kind = .deuteranopia,
        date: Date = Date()
    ) -> PaletteHealthReport {
        let health = PaletteHealth.score(colors)
        let rows = contrastRows(for: colors)
        let confusable = ColorBlindness.confusablePairs(colors, as: kind)
        let roles = roleByIndex(for: colors)

        let failures = rows.filter { $0.tone == .fail }
        let warnings = rows.filter { $0.tone == .warn }
        let issueCount = failures.count + confusable.count

        return PaletteHealthReport(
            paletteName: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Your brand palette"
                : name.trimmingCharacters(in: .whitespacesAndNewlines),
            preparedDate: date.formatted(.dateTime.year().month(.abbreviated).day()),
            health: health,
            entries: colors.enumerated().map { index, swatch in
                Entry(
                    index: index,
                    swatch: swatch,
                    role: roles[index] ?? "Secondary",
                    cmyk: cmykString(for: swatch)
                )
            },
            summary: summary(
                overall: health.overall,
                failures: failures,
                warnings: warnings,
                confusable: confusable,
                colors: colors,
                kind: kind
            ),
            issueCount: issueCount,
            contrastRows: rows,
            colorBlindKind: kind,
            simulated: ColorBlindness.simulate(colors, as: kind),
            colorBlindFinding: confusable.isEmpty
                ? "All \(colors.count) colors stay distinguishable under \(kind.label.lowercased()) — good separation by hue and lightness."
                : "\(colors[confusable[0].first].name) and \(colors[confusable[0].second].name) collapse to nearly the same tone. If they signal different things (e.g. success vs. error), those viewers can't tell them apart.",
            fixes: fixes(failures: failures, confusable: confusable, colors: colors, kind: kind)
        )
    }

    /// Matches the web's `cmykString()` — the print-side numbers a client's printer asks for.
    private static func cmykString(for swatch: PaletteColor) -> String {
        let v = ColorMath.cmyk(red: swatch.red, green: swatch.green, blue: swatch.blue)
        return "\(v.c) / \(v.m) / \(v.y) / \(v.k)"
    }

    /// Measures the pairing a designer would actually use for one surface: white on dark or vivid
    /// surfaces, the palette's darkest colour on light ones. Index-based so the same surface can
    /// be re-measured after an edit.
    static func measurePair(in colors: [PaletteColor], at index: Int) -> ContrastRow {
        let luminances = colors.map {
            ContrastCalculator.relativeLuminance(red: $0.red, green: $0.green, blue: $0.blue)
        }
        let darkestIndex = luminances.firstIndex(of: luminances.min() ?? 0) ?? 0
        let background = colors[index]
        let foreground = luminances[index] >= 0.4
            ? colors[darkestIndex]
            : PaletteColor(red: 1, green: 1, blue: 1, dominance: 0)

        let ratio = ContrastCalculator.ratio(
            r1: foreground.red, g1: foreground.green, b1: foreground.blue,
            r2: background.red, g2: background.green, b2: background.blue
        )
        let grade = ContrastCalculator.verdict(for: ratio).bestGrade

        return ContrastRow(
            foreground: foreground,
            background: background,
            backgroundName: background.name,
            backgroundIndex: index,
            ratio: ratio,
            ratioText: String(format: "%.2f:1", ratio),
            verdict: grade == "Fail" ? "Fails" : grade,
            tone: grade == "AAA" || grade == "AA" ? .pass : grade == "AA Large" ? .warn : .fail
        )
    }

    /// Every surface except the darkest — that one is the text colour, not a background — worst
    /// first, so the report leads with what needs attention.
    static func contrastRows(for colors: [PaletteColor]) -> [ContrastRow] {
        guard colors.count >= 2 else { return [] }
        let luminances = colors.map {
            ContrastCalculator.relativeLuminance(red: $0.red, green: $0.green, blue: $0.blue)
        }
        let darkestIndex = luminances.firstIndex(of: luminances.min() ?? 0) ?? 0
        return colors.indices
            .filter { $0 != darkestIndex }
            .map { measurePair(in: colors, at: $0) }
            .sorted { $0.ratio < $1.ratio }
    }

    /// Deterministic role assignment: most saturated is the accent, lightest of the rest is the
    /// surface, darkest of what remains is the text. Guidance in the report, never part of the
    /// score.
    static func roleByIndex(for colors: [PaletteColor]) -> [Int: String] {
        guard !colors.isEmpty else { return [:] }
        let saturations = colors.map {
            ColorMath.hsl(fromRed: $0.red, green: $0.green, blue: $0.blue).saturation
        }
        let luminances = colors.map {
            ContrastCalculator.relativeLuminance(red: $0.red, green: $0.green, blue: $0.blue)
        }

        var roles: [Int: String] = [:]
        for index in colors.indices { roles[index] = "Secondary" }

        let accent = colors.indices.max { saturations[$0] < saturations[$1] } ?? 0
        let surface = colors.indices
            .filter { $0 != accent }
            .max { luminances[$0] < luminances[$1] } ?? accent
        let text = colors.indices
            .filter { $0 != accent && $0 != surface }
            .min { luminances[$0] < luminances[$1] } ?? surface

        roles[accent] = "Accent"
        roles[surface] = "Surface"
        roles[text] = "Text"
        return roles
    }

    private static func summary(
        overall: Int,
        failures: [ContrastRow],
        warnings: [ContrastRow],
        confusable: [ColorBlindness.ConfusablePair],
        colors: [PaletteColor],
        kind: ColorBlindness.Kind
    ) -> String {
        let gradeWord: String
        switch overall {
        case 85...: gradeWord = "An excellent, well-rounded palette"
        case 70...: gradeWord = "A confident, balanced palette"
        case 55...: gradeWord = "A workable palette with room to tighten up"
        default: gradeWord = "This palette needs attention before shipping"
        }

        var parts: [String] = []
        if let worst = failures.first {
            parts.append("white/dark text on \(worst.backgroundName) fails contrast (\(worst.ratioText))")
        }
        if let pair = confusable.first {
            parts.append("\(colors[pair.first].name) and \(colors[pair.second].name) are hard to tell apart under \(kind.label.lowercased())")
        }

        let issueCount = failures.count + confusable.count
        let lead: String
        if issueCount == 0 {
            if warnings.isEmpty {
                lead = "\(gradeWord). No accessibility issues found — every text pairing and color-blind check passes."
            } else {
                let phrase = warnings.count == 1
                    ? "one pairing only passes"
                    : "\(warnings.count) pairings only pass"
                lead = "\(gradeWord). No blocking issues — \(phrase) for large text."
            }
        } else {
            let count = issueCount == 1 ? "One real problem" : "\(issueCount) real problems"
            lead = "\(gradeWord). \(count) to fix: \(parts.joined(separator: "; "))."
        }
        return "\(lead) Everything below is measured, not guessed."
    }

    private static func fixes(
        failures: [ContrastRow],
        confusable: [ColorBlindness.ConfusablePair],
        colors: [PaletteColor],
        kind: ColorBlindness.Kind
    ) -> [Fix] {
        guard !(failures.isEmpty && confusable.isEmpty) else { return [] }

        var fixes: [Fix] = failures.prefix(1).map { row in
            Fix(
                title: "Fix · \(row.backgroundName) text contrast",
                // Diverges from the web, which points at the Lab's one-click auto-remap — a Pro
                // feature with no iOS equivalent yet. Pointing at it would be an instruction the
                // reader cannot follow, so this names what this app can actually do today.
                body: "Text on \(row.backgroundName) currently measures \(row.ratioText), below WCAG AA. Tap the swatch to edit it and lighten or darken until it passes, keeping the hue."
            )
        }

        if let pair = confusable.first {
            fixes.append(
                Fix(
                    title: "Fix · \(colors[pair.first].name) vs \(colors[pair.second].name) separation",
                    body: "These two converge under \(kind.label.lowercased()). Widen the hue gap or vary lightness so they stay distinct as color-coded signals."
                )
            )
        }
        return fixes
    }
}
