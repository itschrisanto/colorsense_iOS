import SwiftUI

/// The tools available on the current palette. Adding a tool should be a matter of adding a case
/// here and handling it in `RootView` — the sheet lays itself out from `allCases`.
///
/// v1 ships two (vault-locked scope: Extractor + WCAG Contrast Checker only). The other web tools
/// — Brand Kit, Palette Health, Website Analyzer, Scheme Generator — are deliberately absent, not
/// forgotten; see CLAUDE.md before adding any of them.
enum Tool: String, CaseIterable, Identifiable {
    case extractor
    case contrast
    case health
    case svg
    case visualizer
    case library

    var id: String { rawValue }

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

/// Collapsed tool picker, presented from the bottom bar. Kept as a sheet rather than a tab bar so
/// the list can grow past the three or four items a tab bar tolerates.
struct ToolsSheet: View {
    let onSelect: (Tool) -> Void

    @Environment(\.dismiss) private var dismiss

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] { AdaptiveColumns.cards(for: dynamicTypeSize) }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Tool.allCases) { tool in
                        Button {
                            dismiss()
                            onSelect(tool)
                        } label: {
                            card(for: tool)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .safeAreaInset(edge: .top) {
                Text("All work on the same palette")
                    .font(BrandFont.ui(13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func card(for tool: Tool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: tool.systemImage)
                .font(.system(size: 20))
                .foregroundStyle(BrandColor.coral)
            Text(tool.title)
                .font(BrandFont.ui(16, weight: .medium))
            Text(tool.summary)
                .font(BrandFont.ui(13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        // Fill the row, do not just sit in it.
        //
        // Cards size to their own content, and the summaries are different lengths, so a row with a
        // one-line card beside a two-line one drew two different-height backgrounds and the grid
        // looked ragged. `LazyVGrid` already gives every row the height of its tallest item; this
        // makes the card take that height instead of leaving a gap under the shorter one. Safe to
        // stretch here because the row's height is definite, unlike the onboarding buttons that
        // were sitting next to a greedy hero.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    Color.gray.sheet(isPresented: .constant(true)) {
        ToolsSheet { _ in }
    }
}
