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
                    paletteAssigner
                    preview
                    verdict
                    VStack(spacing: 14) {
                        ColorPicker("Text", selection: $viewModel.foreground, supportsOpacity: false)
                        ColorPicker("Background", selection: $viewModel.background, supportsOpacity: false)
                    }
                    .font(BrandFont.ui(16, weight: .medium))
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

    // MARK: - Palette assigner

    /// Each palette colour with its own Text and BG buttons, ported from the web panel. Two
    /// separate swatch rows made you hunt for the same colour twice and never showed which
    /// pairing was currently on screen; here every swatch states its own role.
    ///
    /// Scrolls horizontally because the palette can hold up to eight colours, which will not fit
    /// across a phone at a legible size.
    private var paletteAssigner: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("YOUR PALETTE · \(viewModel.paletteColors.count) COLORS")
                    .font(BrandFont.ui(11, weight: .bold))
                    .foregroundStyle(BrandColor.coral)
                Text("Tap Text or BG to swap any color in.")
                    .font(BrandFont.ui(12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.paletteColors) { swatch in
                        assignerCard(swatch)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.top, 4)
    }

    private func assignerCard(_ swatch: PaletteColor) -> some View {
        let role = viewModel.role(of: swatch)
        return VStack(spacing: 0) {
            swatch.color
                .frame(height: 54)
            Text(swatch.hex)
                .brandMono(11, weight: .medium)
                .padding(.vertical, 6)
            HStack(spacing: 0) {
                roleButton(
                    "Text",
                    isActive: role == .text,
                    activeTint: BrandColor.coral,
                    accessibilityLabel: "Use \(swatch.name) as text color"
                ) {
                    viewModel.assign(swatch, to: .text)
                }
                roleButton(
                    "BG",
                    isActive: role == .background,
                    activeTint: .primary,
                    accessibilityLabel: "Use \(swatch.name) as background color"
                ) {
                    viewModel.assign(swatch, to: .background)
                }
            }
        }
        .frame(width: 116)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.primary.opacity(0.12), lineWidth: 1)
        }
    }

    private func roleButton(
        _ title: String,
        isActive: Bool,
        activeTint: Color,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Text(title)
                    .font(BrandFont.ui(11, weight: .bold))
                if isActive {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isActive ? activeTint : Color.clear)
            .foregroundStyle(isActive ? Color(.systemBackground) : .secondary)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
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
