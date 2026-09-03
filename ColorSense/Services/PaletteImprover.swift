import Foundation

/// Suggesting a better palette, without inventing any colour maths.
///
/// This composes two existing ports rather than adding a third: `PaletteGenerator` (the web's
/// `relatedPalette()`) proposes candidates, and `PaletteHealth` (the web's `scorePalette()`) judges
/// them. The only new logic here is the search, which is deliberate: a bespoke "make this palette
/// better" heuristic would be a fourth opinion about colour that the web does not share and could
/// not be checked against anything.
///
/// **Locked swatches are the constraint, not a hint.** They are passed as the generator's anchors
/// and copied into every candidate untouched, so a reader who has locked their brand colour is
/// promised that it survives. That promise is the reason this feature is worth having: "regenerate
/// until it looks nicer" is what Generate already does.
enum PaletteImprover {

    struct Suggestion: Equatable, Identifiable {
        var id: String { colors.map(\.hex).joined() }
        let colors: [PaletteColor]
        let before: PaletteHealth.Result
        let after: PaletteHealth.Result

        /// Only worth showing if it is actually better. Equal scores are not an improvement, and
        /// offering one would teach a reader to distrust the button.
        var isWorthShowing: Bool { after.overall > before.overall }
        var gain: Int { after.overall - before.overall }
    }

    /// Searches for a higher-scoring palette that keeps every locked swatch.
    ///
    /// **The search is stochastic, and that is inherited rather than chosen.** `PaletteGenerator`
    /// jitters hue, saturation and lightness with `Double.random` on every call, because the web's
    /// `relatedPalette()` does, so the same palette asked twice can produce two different
    /// suggestions. An earlier version of this comment claimed the opposite and a test caught it.
    ///
    /// That turns out to suit the feature: declining a suggestion and asking again gives another
    /// option rather than the same one back. What *is* guaranteed is the contract the tests pin:
    /// locked colours never move, slot ids survive, and nothing is offered unless it scores higher.
    ///
    /// `attempts` reaches past `PaletteGenerator.wideningIteration`, where the generator's schemes
    /// widen from tight harmonies to bolder ones, because a palette that scores badly is often one
    /// no tight harmony can rescue.
    static func improve(_ palette: ExtractedPalette, attempts: Int = 48) -> Suggestion? {
        let current = palette.colors
        guard current.count >= 2 else { return nil }

        let before = PaletteHealth.score(current)
        let locked = current.filter(\.isLocked)
        let anchors = locked.isEmpty ? palette.anchors : locked

        var best: (colors: [PaletteColor], result: PaletteHealth.Result)?

        for iteration in 0..<attempts {
            let generated = PaletteGenerator.colors(
                anchoredTo: anchors,
                count: current.count,
                iteration: iteration
            )
            // Locked slots are carried across verbatim, and every slot keeps its id so applying a
            // suggestion animates in place rather than rebuilding the bands.
            let candidate = zip(current, generated).map { existing, replacement -> PaletteColor in
                guard !existing.isLocked else { return existing }
                var updated = replacement
                updated.id = existing.id
                return updated
            }

            let result = PaletteHealth.score(candidate)
            if result.overall > (best?.result.overall ?? before.overall) {
                best = (candidate, result)
            }
        }

        guard let best else { return nil }
        let suggestion = Suggestion(colors: best.colors, before: before, after: best.result)
        return suggestion.isWorthShowing ? suggestion : nil
    }
}
