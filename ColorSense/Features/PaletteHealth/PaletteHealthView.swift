import SwiftUI

/// The Palette Health tool: a score, a breakdown, and the client-ready report.
///
/// The web app's page order is followed deliberately — score, dimensions, then the written report
/// — for the same reason `ColorDetailView` follows `ColorDetailCard.tsx`: someone who knows one
/// product should not have to relearn the other.
///
/// No PDF export. On the web the report exports as a PDF; here it does not, because that is a
/// desktop deliverable and the web app already does it well.
struct PaletteHealthView: View {
    let palette: ExtractedPalette

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var seenAs: ColorBlindness.Kind = .deuteranopia

    private var report: PaletteHealthReport {
        PaletteHealthReport.build(for: palette.colors, name: "", seenAs: seenAs)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if palette.colors.count < 2 {
                        notEnoughColors
                    } else {
                        scoreCard
                        dimensions
                        summarySection
                        rolesSection
                        contrastSection
                        colorBlindSection
                        if !report.fixes.isEmpty { fixesSection }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Palette health")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var notEnoughColors: some View {
        VStack(spacing: 8) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 34))
                .foregroundStyle(BrandColor.coral)
            Text("Add another color")
                .font(BrandFont.ui(17, weight: .bold))
            Text("A palette needs at least two colors before it can be scored.")
                .font(BrandFont.ui(14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Score

    private var scoreCard: some View {
        let health = report.health
        return HStack(alignment: .center, spacing: 18) {
            VStack(spacing: 2) {
                Text(health.grade.rawValue)
                    .font(BrandFont.display(52))
                Text("Grade")
                    .font(BrandFont.ui(11, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 84)
            .padding(.vertical, 14)
            .background(tint(for: health.overall).opacity(0.16))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(health.overall)")
                        .font(BrandFont.display(40))
                    Text("/ 100")
                        .font(BrandFont.ui(14))
                        .foregroundStyle(.secondary)
                }
                Text(report.preparedDate)
                    .font(BrandFont.ui(12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var dimensions: some View {
        VStack(spacing: 10) {
            ForEach(report.health.dimensions, id: \.label) { dimension in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(dimension.label)
                            .font(BrandFont.ui(15, weight: .bold))
                        Spacer()
                        Text("\(dimension.score)")
                            .brandMono(15, weight: .bold)
                            .foregroundStyle(tint(for: dimension.score))
                    }
                    // A bar rather than a number alone: five scores are far easier to compare by
                    // length than by reading five separate figures.
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.primary.opacity(0.08))
                            Capsule()
                                .fill(tint(for: dimension.score))
                                .frame(width: proxy.size.width * CGFloat(dimension.score) / 100)
                        }
                    }
                    .frame(height: 6)

                    Text(dimension.detail)
                        .font(BrandFont.ui(12))
                        .foregroundStyle(.secondary)
                    Text(dimension.tip)
                        .font(BrandFont.ui(13))
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    // MARK: - Report

    private var summarySection: some View {
        section("Summary") {
            Text(report.summary)
                .font(BrandFont.ui(14))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var rolesSection: some View {
        section("Roles") {
            VStack(spacing: 8) {
                ForEach(report.entries) { entry in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(entry.swatch.color)
                            .frame(width: 34, height: 34)
                            .overlay {
                                RoundedRectangle(cornerRadius: 7)
                                    .strokeBorder(.primary.opacity(0.12), lineWidth: 0.5)
                            }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.swatch.name)
                                .font(BrandFont.ui(14, weight: .medium))
                            Text(entry.swatch.hex)
                                .brandMono(11)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(entry.role)
                                .font(BrandFont.ui(12, weight: .bold))
                            Text(entry.cmyk)
                                .brandMono(10)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var contrastSection: some View {
        section("Text contrast") {
            VStack(spacing: 8) {
                ForEach(report.contrastRows) { row in
                    HStack(spacing: 12) {
                        // The measured pairing itself, shown as it was measured — a swatch of the
                        // surface with the foreground actually used on it.
                        Text("Aa")
                            .font(BrandFont.ui(15, weight: .bold))
                            .foregroundStyle(row.foreground.color)
                            .frame(width: 44, height: 34)
                            .background(row.background.color)
                            .clipShape(RoundedRectangle(cornerRadius: 7))

                        Text(row.backgroundName)
                            .font(BrandFont.ui(14))
                            .lineLimit(1)
                        Spacer()
                        Text(row.ratioText)
                            .brandMono(12)
                            .foregroundStyle(.secondary)
                        Text(row.verdict)
                            .font(BrandFont.ui(11, weight: .bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(tone(row.tone).opacity(0.18))
                            .foregroundStyle(tone(row.tone))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var colorBlindSection: some View {
        section("Color vision") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Simulate", selection: $seenAs) {
                    ForEach(ColorBlindness.Kind.allCases) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                .pickerStyle(.segmented)

                Text("\(report.colorBlindKind.label) · \(report.colorBlindKind.prevalence)")
                    .font(BrandFont.ui(12))
                    .foregroundStyle(.secondary)

                // The palette as everyone sees it, above the same palette as these viewers do.
                // Side by side is the only way the collapse reads.
                VStack(spacing: 4) {
                    swatchStrip(palette.colors)
                    swatchStrip(report.simulated)
                }

                Text(report.colorBlindFinding)
                    .font(BrandFont.ui(13))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func swatchStrip(_ colors: [PaletteColor]) -> some View {
        HStack(spacing: 3) {
            ForEach(colors) { swatch in
                RoundedRectangle(cornerRadius: 5)
                    .fill(swatch.color)
                    .frame(height: 30)
            }
        }
    }

    private var fixesSection: some View {
        section("What to fix") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(report.fixes) { fix in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(fix.title)
                            .font(BrandFont.ui(14, weight: .bold))
                        Text(fix.body)
                            .font(BrandFont.ui(13))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: - Pieces

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(BrandFont.ui(11, weight: .bold))
                .foregroundStyle(.secondary)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    /// The web's `scoreColor()` bands, in this app's palette rather than Tailwind's.
    private func tint(for score: Int) -> Color {
        switch score {
        case 85...: return BrandColor.teal
        case 70...: return .blue
        case 55...: return BrandColor.yellow
        case 40...: return .orange
        default: return BrandColor.coral
        }
    }

    private func tone(_ tone: PaletteHealthReport.ContrastRow.Tone) -> Color {
        switch tone {
        case .pass: return BrandColor.teal
        case .warn: return .orange
        case .fail: return BrandColor.coral
        }
    }
}
