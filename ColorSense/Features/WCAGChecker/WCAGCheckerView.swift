import SwiftUI

/// Presented as a tool sheet from `RootView`, seeded with the app's current palette.
///
/// The preview is the whole top of the screen rather than a small card: contrast is the thing
/// being judged, so the type has to be big enough to actually judge. Everything else — the ratio,
/// the grades, the pickers — sits under it.
struct WCAGCheckerView: View {
    @State private var viewModel: WCAGCheckerViewModel
    @Environment(\.dismiss) private var dismiss

    init(palette: ExtractedPalette = .sample) {
        _viewModel = State(initialValue: WCAGCheckerViewModel(palette: palette))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    preview
                    verdict
                    VStack(spacing: 18) {
                        colorRow(
                            title: "Text",
                            selection: $viewModel.foreground,
                            assign: { viewModel.foreground = $0 }
                        )
                        colorRow(
                            title: "Background",
                            selection: $viewModel.background,
                            assign: { viewModel.background = $0 }
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle("Contrast")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { viewModel.swap() } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    .accessibilityLabel("Swap text and background colors")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationBackground(.ultraThinMaterial)
        .presentationCornerRadius(28)
        .presentationDragIndicator(.visible)
    }

    // MARK: - Preview

    private var preview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Large text")
                .font(BrandFont.ui(28, weight: .bold))
            Text("Normal body text, set at the size most interface copy actually uses.")
                .font(BrandFont.ui(15))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(viewModel.foreground)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(viewModel.background)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    // MARK: - Verdict

    private var verdict: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(String(format: "%.2f:1", viewModel.ratio))
                    .font(BrandFont.display(46))
                Text(viewModel.rating.label)
                    .font(BrandFont.ui(11, weight: .bold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(tint(for: viewModel.rating.tone).opacity(0.16))
                    .foregroundStyle(tint(for: viewModel.rating.tone))
                    .clipShape(Capsule())
            }

            HStack(spacing: 10) {
                levelChip("Normal text", viewModel.normalTextLevel)
                levelChip("Large text", viewModel.largeTextLevel)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal, 20)
    }

    private func levelChip(_ title: String, _ level: ContrastCalculator.Level) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(BrandFont.ui(12))
                .foregroundStyle(.secondary)
            Text(label(for: level))
                .font(BrandFont.ui(15, weight: .bold))
                .foregroundStyle(color(for: level))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color(for: level).opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Pickers

    /// A system colour picker plus one-tap shortcuts for the colours already in the palette —
    /// the checker works on the same palette as every other tool.
    private func colorRow(
        title: String,
        selection: Binding<Color>,
        assign: @escaping (Color) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ColorPicker(title, selection: selection, supportsOpacity: false)
                .font(BrandFont.ui(16, weight: .medium))

            HStack(spacing: 8) {
                ForEach(viewModel.paletteColors) { swatch in
                    Button {
                        assign(swatch.color)
                    } label: {
                        RoundedRectangle(cornerRadius: 9)
                            .fill(swatch.color)
                            .frame(height: 38)
                            .overlay {
                                RoundedRectangle(cornerRadius: 9)
                                    .strokeBorder(.primary.opacity(0.15), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Use \(swatch.name) as \(title.lowercased())")
                }
            }
        }
    }

    // MARK: - Labels

    private func label(for level: ContrastCalculator.Level) -> String {
        switch level {
        case .fail: return "Fail"
        case .aa: return "AA"
        case .aaa: return "AAA"
        }
    }

    private func color(for level: ContrastCalculator.Level) -> Color {
        switch level {
        case .fail: return .red
        case .aa: return BrandColor.teal
        case .aaa: return .green
        }
    }

    private func tint(for tone: ContrastCalculator.Rating.Tone) -> Color {
        switch tone {
        case .good: return .green
        case .warning: return .orange
        case .bad: return .red
        }
    }
}

#Preview {
    WCAGCheckerView(palette: .sample)
}
