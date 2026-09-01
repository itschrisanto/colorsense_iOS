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

    /// Specimen copy and sizes ported from the web app's WCAG panel. The point of a preview is to
    /// judge readability, so it shows real sentences at the sizes the thresholds are actually
    /// about — 16pt body and a 30pt headline — rather than two short labels.
    private var preview: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Normal text — 16px")
                .font(BrandFont.ui(14, weight: .medium))
                .opacity(0.8)
            Text("The quick brown fox jumps over the lazy dog")
                .font(BrandFont.ui(21, weight: .bold))
                .padding(.top, 4)
                .fixedSize(horizontal: false, vertical: true)
            Text("Large headline — 30px bold")
                .font(BrandFont.ui(28, weight: .bold))
                .padding(.top, 18)
                .fixedSize(horizontal: false, vertical: true)
            Text("Body copy at 16px regular weight to preview how readable your pairing is for paragraphs and labels.")
                .font(BrandFont.ui(16))
                .padding(.top, 4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(viewModel.foreground)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
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

            Text("Best grade: \(viewModel.verdict.bestGrade)")
                .font(BrandFont.ui(13))
                .foregroundStyle(.secondary)

            // All four checks, spelled out with their thresholds, as the web panel shows them.
            // Two summary chips hid which specific requirement a pairing missed.
            VStack(spacing: 8) {
                ForEach(viewModel.verdict.checks) { check in
                    verdictRow(check)
                }
            }
            .padding(.horizontal, 14)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal, 20)
    }

    private func verdictRow(_ check: ContrastCalculator.Verdict.Check) -> some View {
        let tint: Color = check.passes ? .green : .red
        return HStack(spacing: 8) {
            Image(systemName: check.passes ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 15))
            Text(check.label)
                .font(BrandFont.ui(13, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 6)
            Text(check.passes ? "PASS" : "FAIL")
                .font(BrandFont.ui(11, weight: .bold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
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
