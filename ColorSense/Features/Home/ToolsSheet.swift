import SwiftUI

/// Everything that can be launched from the palette. Extractor is intentionally an action rather
/// than a panel: it replaces the current palette and returns immediately. The remaining cases live
/// together in `ToolWorkspaceView`, where changing tools preserves each panel's local state.
enum Tool: String, CaseIterable, Identifiable {
    case extractor
    case contrast
    case health
    case svg
    case visualizer
    case library

    var id: String { rawValue }

    static let panels: [Tool] = [.contrast, .health, .svg, .visualizer, .library]

    var title: String {
        switch self {
        case .extractor: return "Extractor"
        case .contrast: return "Contrast"
        case .health: return "Health"
        case .svg: return "SVG Recolor"
        case .visualizer: return "Visualizer"
        case .library: return "Library"
        }
    }

    var systemImage: String {
        switch self {
        case .extractor: return "eyedropper"
        case .contrast: return "circle.lefthalf.filled"
        case .health: return "heart.text.square"
        case .svg: return "wand.and.stars"
        case .visualizer: return "rectangle.3.group"
        case .library: return "books.vertical"
        }
    }

    var summary: String {
        switch self {
        case .extractor: return "Pull a palette from a photo"
        case .contrast: return "Check WCAG AA / AAA"
        case .health: return "Score the palette and get a report"
        case .svg: return "Recolor an SVG with this palette"
        case .visualizer: return "See the palette in real designs"
        case .library: return "Your saved palettes and the curated library"
        }
    }
}

/// The persistent lens switcher at the bottom of the shared tool workspace.
///
/// It is the palette dock, in the same capsule, built from the same `DockButton` and the same
/// press feedback. Two bars in the same position on consecutive screens have to be one design, and
/// the dock is the one that was settled first.
///
/// Two things differ from the dock, and both follow from what is behind the glass. The dock floats
/// on the palette and measures its ink against the last swatch; nothing here sits on a swatch, so
/// the ink is `.primary`. And these items are a *selection* rather than five actions, which the
/// dock has no vocabulary for. Selection is carried by ink weight, not by a coral fill: coral means
/// "the one primary action" on the dock, and the same colour cannot also mean "you are here" on a
/// bar that is otherwise identical. The tool's name is in the navigation title directly above.
struct ToolStrip: View {
    @Binding var selection: Tool

    var body: some View {
        // Fills the capsule while the tools fit and scrolls once they do not.
        //
        // The strip was chosen over a tab bar because a tab bar tolerates three or four items and
        // this list is still growing. A fixed row inside a capsule would quietly reacquire that
        // ceiling at six or seven, so `ViewThatFits` keeps both properties: today's five spread
        // across the capsule exactly as the dock's five do, and the day a sixth or a ninth lands
        // the row scrolls instead of squeezing every target below a thumb.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
                ForEach(Tool.panels) { tool in
                    button(for: tool)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Tool.panels) { tool in
                        button(for: tool).frame(width: 64)
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .dockCapsule(foreground: .primary)
    }

    private func button(for tool: Tool) -> some View {
        // Full ink for the tool being used, and the rest stepped back. Measured against the
        // material rather than a swatch, which is why this does not go through
        // `ContrastCalculator` the way the dock's own foreground does.
        DockButton(
            tool.systemImage,
            label: tool.title,
            foreground: selection == tool ? .primary : .primary.opacity(0.55)
        ) {
            selection = tool
        }
        .accessibilityAddTraits(selection == tool ? .isSelected : [])
    }
}

#Preview {
    ToolStrip(selection: .constant(.contrast))
}
