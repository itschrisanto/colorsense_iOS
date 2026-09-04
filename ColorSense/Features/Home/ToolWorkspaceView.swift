import SwiftUI

/// One palette, viewed through several tools.
///
/// Every panel stays mounted while this workspace is open. Hiding a panel rather than replacing it
/// is deliberate: switching away must not forget an imported SVG, a selected Visualizer scene, a
/// Library tab, or a contrast pairing. Extractor and Share are actions and do not belong here.
struct ToolWorkspaceView: View {
    let isPro: Bool

    @Environment(PaletteStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selection: Tool

    init(initialTool: Tool = .contrast, isPro: Bool = false) {
        _selection = State(initialValue: Tool.panels.contains(initialTool) ? initialTool : .contrast)
        self.isPro = isPro
    }

    var body: some View {
        // The workspace owns the navigation chrome, and the panels no longer carry their own.
        //
        // Each tool used to be its own `NavigationStack` with its own Back. Inside one workspace
        // that would be five nested stacks and a bar that belongs to whichever panel happens to be
        // visible. One stack here means one title that follows the strip and one Back, which is
        // also the only way out: a `fullScreenCover` has no swipe to dismiss.
        NavigationStack {
            ZStack {
                ForEach(Tool.panels) { tool in
                    panel(tool)
                        .opacity(selection == tool ? 1 : 0)
                        .allowsHitTesting(selection == tool)
                        .accessibilityHidden(selection != tool)
                        .zIndex(selection == tool ? 1 : 0)
                }
            }
            .navigationTitle(selection.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { BackToPalette { dismiss() } }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                ToolStrip(selection: $selection)
            }
        }
        .onAppear {
            AnalyticsService.capture(.toolOpened, ["tool": selection.rawValue])
        }
        .onChange(of: selection) { _, tool in
            AnalyticsService.capture(.toolOpened, ["tool": tool.rawValue])
        }
    }

    @ViewBuilder
    private func panel(_ tool: Tool) -> some View {
        switch tool {
        case .contrast:
            WCAGCheckerView(isPro: isPro, palette: store.palette)
        case .health:
            PaletteHealthView(
                palette: store.palette,
                isPro: isPro,
                onRemap: { index, swatch in
                    withAnimation(PaletteMotion.recolor(reduceMotion: reduceMotion)) {
                        store.replace(at: index, with: swatch)
                    }
                }
            )
        case .svg:
            SvgRecolorView(palette: store.palette, isPro: isPro, isActive: selection == .svg)
        case .visualizer:
            VisualizerView(isPro: isPro, isActive: selection == .visualizer)
        case .library:
            LibraryView()
        case .extractor:
            EmptyView()
        }
    }
}

#Preview {
    ToolWorkspaceView()
        .environment(PaletteStore())
}
