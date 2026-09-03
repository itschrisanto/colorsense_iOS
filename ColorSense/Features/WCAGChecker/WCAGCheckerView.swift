import SwiftUI

/// Presented as a tool sheet from `RootView`, seeded with the app's current palette.
///
/// The preview is the whole top of the screen rather than a small card: contrast is the thing
/// being judged, so the type has to be big enough to actually judge. Everything else — the ratio,
/// the grades, the pickers — sits under it.
struct WCAGCheckerView: View {
    /// Pro gates the fix, not the checking. The checker itself stays free and unlimited — see
    /// CLAUDE.md, which is explicit that this tool is never paywalled.
    let isPro: Bool

    @State private var viewModel: WCAGCheckerViewModel
    @State private var fixIsPresented = false
    @Environment(\.dismiss) private var dismiss

    init(isPro: Bool = false, palette: ExtractedPalette = .sample) {
        self.isPro = isPro
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
            .safeAreaInset(edge: .bottom, spacing: 0) { fixItBar }
            .sheet(isPresented: $fixIsPresented) {
                if let target = fixTarget, let fix = viewModel.suggestedFix(target: target) {
                    ContrastFixSheet(
                        title: "Fix contrast",
                        isPro: isPro,
                        proposals: [
                            .init(
                                id: 0,
                                problem: "Your text measures \(String(format: "%.2f:1", viewModel.ratio)) on this background, short of \(target >= 7 ? "AAA (7:1)" : "AA (4.5:1)"). Going \(fix.wentLighter ? "lighter" : "darker") reaches it while keeping the hue.",
                                original: viewModel.foregroundSwatch,
                                proposed: fix.swatch,
                                against: viewModel.backgroundSwatch,
                                changingIsForeground: true,
                                currentRatio: viewModel.ratio,
                                newRatio: fix.ratio,
                                wentLighter: fix.wentLighter
                            )
                        ],
                        onApply: { proposal in
                            withAnimation(.snappy) { viewModel.foreground = proposal.proposed.color }
                        }
                    )
                    .presentationDetents([.medium, .large])
                }
            }
            .navigationTitle("Contrast")
            // Once per opening rather than on each ratio change: the question is whether the
            // checker gets used at all, not how much the sliders move.
            .onAppear { AnalyticsService.capture(.contrastChecked) }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                BackToPalette { dismiss() }
                // Trailing, and labelled. Sitting on the leading edge next to Back, a bare
                // up/down arrow read as a second navigation control rather than as an action on
                // the two colours, which is what Chris ran into.
                ToolbarItem(placement: .topBarTrailing) {
                    Button { viewModel.swap() } label: {
                        Label("Swap", systemImage: "arrow.up.arrow.down")
                            .labelStyle(.titleAndIcon)
                    }
                    .accessibilityLabel("Swap text and background colors")
                }
            }
        }
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

    /// Which grade the fix should aim for, or nil when the pairing already clears AAA.
    ///
    /// Climbing rather than only rescuing: a pairing that passes AA is still offered the nudge to
    /// AAA, which is what keeps this control present — and therefore discoverable — instead of
    /// appearing only when something is broken.
    private var fixTarget: Double? {
        if viewModel.ratio < 4.5 { return 4.5 }
        if viewModel.ratio < 7 { return 7 }
        return nil
    }

    /// "Fix it" — nudges the *text* colour to the nearest lightness that clears the next grade.
    ///
    /// It lives in a bottom bar rather than inline in the verdict for a reason found in testing:
    /// inline, it only appeared when a pairing failed, so anyone whose colours already passed
    /// never learned the feature existed at all. Pinned to the bottom it is always visible, and
    /// says what it would do before it is pressed.
    ///
    /// Locked for free users the same way the Pro export formats are — shown, labelled, inert,
    /// and with no route to a purchase anywhere near it, per guideline 3.1.1.
    private var fixItBar: some View {
        let target = fixTarget
        let fix = target.flatMap { viewModel.suggestedFix(target: $0) }

        return VStack(spacing: 0) {
            Divider()
            Group {
                if let target, let fix {
                    Button {
                        // Proposes rather than applies — changing someone's colour without asking
                        // is the app overruling its user on the one thing the product is about.
                        // Free users open the same sheet: it shows the fix in full and names Pro
                        // as what applies it.
                        fixIsPresented = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: isPro ? "wand.and.stars" : "lock.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Fix it — reach \(target >= 7 ? "AAA" : "AA")")
                                .font(BrandFont.ui(15, weight: .medium))
                            if !isPro { proBadge }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                    // Coral means there is something to fix; grey means there is not. Being
                    // locked must not borrow the grey, or a free user reads "nothing to fix"
                    // when the truth is "something to fix, and this is how".
                    .foregroundStyle(.white)
                    .background {
                        RoundedRectangle(cornerRadius: 13)
                            .fill(BrandColor.coral.opacity(isPro ? 1 : 0.55))
                    }
                    .accessibilityLabel(isPro
                        ? "Fix the text color to reach \(target >= 7 ? "triple A" : "double A")"
                        : "Fix it, a Pro feature")
                } else {
                    // Either already AAA, or no lightness of this hue can get there. Both are
                    // real outcomes and both are worth saying rather than showing nothing.
                    Label(
                        target == nil
                            ? "Passes AAA — nothing to fix"
                            : "No lightness of this hue reaches the next grade",
                        systemImage: target == nil ? "checkmark.circle.fill" : "info.circle"
                    )
                    .font(BrandFont.ui(14))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .background(.bar)
    }

    private var proBadge: some View {
        Text("PRO")
            .font(BrandFont.ui(10, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            // On a coral fill, not on a card — so the badge is white-on-white-ish rather than
            // the purple-on-light it uses in the share sheet.
            .background(.white.opacity(0.28))
            .foregroundStyle(.white)
            .clipShape(Capsule())
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
