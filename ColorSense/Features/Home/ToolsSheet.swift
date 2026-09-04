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

/// The persistent lens switcher at the bottom of the shared tool workspace. It scrolls instead of
/// squeezing labels, so adding a future panel does not make today's five targets too small.
struct ToolStrip: View {
    @Binding var selection: Tool

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Tool.panels) { tool in
                        Button { selection = tool } label: {
                            VStack(spacing: 4) {
                                Image(systemName: tool.systemImage)
                                    .font(.system(size: 17, weight: .semibold))
                                Text(tool.title)
                                    .font(BrandFont.ui(11, weight: .medium))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(selection == tool ? Color.white : Color.primary)
                            .frame(minWidth: 68, minHeight: 48)
                            .padding(.horizontal, 4)
                            .background {
                                Capsule()
                                    .fill(selection == tool ? BrandColor.coral : Color.clear)
                            }
                            .contentShape(.capsule)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(tool.title)
                        .accessibilityAddTraits(selection == tool ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
            }
        }
        .background(.bar)
    }
}

#Preview {
    ToolStrip(selection: .constant(.contrast))
}
