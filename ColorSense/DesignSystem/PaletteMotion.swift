import SwiftUI

/// How the palette moves when it changes.
///
/// One place for the timings, for the same reason `BrandColor` and `BrandFont` exist: the palette
/// is mutated from six call sites across three files, and motion that differs between them reads
/// as inconsistency rather than intent.
///
/// Every case returns an optional and every case can return `nil`, because Reduce Motion is not
/// handled for you — `withAnimation` runs regardless of the setting. Passing `nil` to
/// `withAnimation` performs the change with no animation at all, which is exactly what a reader
/// who has asked for less motion should get: the palette still updates, it just does not travel.
enum PaletteMotion {
    /// Generate: the same bands take new colors.
    ///
    /// Slower than a tap response would normally justify, deliberately. The point of animating
    /// Generate is that locked swatches visibly *hold still* while the rest move, which is the
    /// clearest explanation of what locking does anywhere in the app — and that reads only if
    /// there is time to see it.
    static func recolor(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.35)
    }

    /// Adding or removing a swatch, where the stack re-divides the available height.
    ///
    /// A spring rather than a curve: bands are resizing against each other, and a little
    /// settle sells that they are sharing a fixed space rather than appearing from nowhere.
    static func structural(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.82)
    }

    /// Extraction, where an entire palette is replaced at once.
    ///
    /// Nothing carries over — every swatch is new — so this is a cross-fade rather than a
    /// journey. Trying to animate position or color here would imply a relationship between the
    /// old palette and the new one that does not exist.
    static func replace(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.4)
    }
}
