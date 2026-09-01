import SwiftUI

/// Presented as a tool sheet from `RootView`, seeded with the app's current palette.
struct WCAGCheckerView: View {
    @State private var viewModel: WCAGCheckerViewModel
    @Environment(\.dismiss) private var dismiss

    init(palette: ExtractedPalette = .sample) {
        _viewModel = State(initialValue: WCAGCheckerViewModel(palette: palette))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    preview
                    ratioCard

                    VStack(spacing: 20) {
                        pickerRow(
                            title: "Text color",
                            selection: $viewModel.foreground,
                            assign: { viewModel.foreground = $0 }
                        )
                        pickerRow(
                            title: "Background color",
                            selection: $viewModel.background,
                            assign: { viewModel.background = $0 }
                        )
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Contrast")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var preview: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(viewModel.background)
            .frame(height: 140)
            .overlay {
                VStack(spacing: 6) {
                    Text("Large text")
                        .font(BrandFont.ui(24, weight: .bold))
                    Text("Normal body text")
                        .font(BrandFont.ui(15))
                }
                .foregroundStyle(viewModel.foreground)
            }
            .padding(.horizontal)
    }

    private var ratioCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(format: "%.2f:1", viewModel.ratio))
                .font(BrandFont.display(40))

            levelRow(title: "Normal text", level: viewModel.normalTextLevel)
            levelRow(title: "Large text", level: viewModel.largeTextLevel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    /// A system color picker plus one-tap shortcuts for the colors already in the palette.
    private func pickerRow(
        title: String,
        selection: Binding<Color>,
        assign: @escaping (Color) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ColorPicker(title, selection: selection, supportsOpacity: false)
                .font(BrandFont.ui(16))

            HStack(spacing: 8) {
                ForEach(viewModel.paletteColors) { swatch in
                    Button {
                        assign(swatch.color)
                    } label: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(swatch.color)
                            .frame(height: 34)
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(.primary.opacity(0.15), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Use \(swatch.name) as \(title.lowercased())")
                }
            }
        }
    }

    private func levelRow(title: String, level: ContrastCalculator.Level) -> some View {
        HStack {
            Text(title)
                .font(BrandFont.ui(15))
            Spacer()
            Text(label(for: level))
                .font(BrandFont.ui(14, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(color(for: level).opacity(0.15))
                .foregroundStyle(color(for: level))
                .clipShape(Capsule())
        }
    }

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
}

#Preview {
    WCAGCheckerView(palette: .sample)
}
