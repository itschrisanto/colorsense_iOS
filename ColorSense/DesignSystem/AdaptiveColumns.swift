import SwiftUI

/// Grid columns that collapse to one at accessibility text sizes.
///
/// A card carrying a title and a line of description cannot survive being held to half the screen
/// width once its text is scaled up — there is no width left for a long word. Measured in the
/// Tools sheet at accessibility-extra-large, where a fixed two-column grid broke "Extractor"
/// across two lines *mid-word*, and the cards beneath it collided.
///
/// Collapsing to a single column rather than letting the columns keep shrinking is Apple's own
/// guidance for this, and it is why `isAccessibilitySize` exists as a distinct threshold rather
/// than a size comparison: it marks the point where the reader has asked for text large enough
/// that side-by-side layouts stop making sense.
enum AdaptiveColumns {
    /// `count` columns at normal text sizes, one at accessibility sizes.
    static func cards(
        _ count: Int = 2,
        spacing: CGFloat = 12,
        for size: DynamicTypeSize
    ) -> [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: spacing),
            count: size.isAccessibilitySize ? 1 : count
        )
    }
}
