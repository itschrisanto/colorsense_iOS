import SwiftUI

/// The color detail card, mirroring the web app's `ColorDetailCard.tsx`: insights, conversions,
/// harmonies and accessibility, all computed on-device and free — matching the brand stance that
/// these are not gated. The web's "Generate Harmonies · AI · Pro" button is deliberately absent
/// (no StoreKit on iOS yet — see CLAUDE.md).
struct ColorDetailView: View {
    let swatch: PaletteColor

    @Environment(\.dismiss) private var dismiss
    @State private var copiedValue: String?

    private var insight: ColorInsight { ColorInsights.insight(for: swatch) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    VStack(alignment: .leading, spacing: 22) {
                        insightSection("Psychology", insight.psychology)
                        insightSection("Meaning", insight.meaning)
                        insightSection("Applications", insight.applications)
                        conversions
                        harmonies
                        accessibility
                        footnote
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .scrollContentBackground(.hidden)
        }
        // Translucent sheet so the palette stays visible behind the card — the color you tapped
        // reads through rather than being replaced by an opaque panel.
        .presentationBackground(.ultraThinMaterial)
        .presentationCornerRadius(28)
        .presentationDragIndicator(.visible)
        // Opens full height because the card is long, but can be dragged down to a half sheet
        // to compare the color against the rest of the palette behind it.
        .presentationDetents([.large, .medium])
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            swatch.color
                .frame(height: 110)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
                }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(swatch.name)
                    .font(BrandFont.ui(22, weight: .bold))
                Button {
                    copy(swatch.hex)
                } label: {
                    HStack(spacing: 4) {
                        Text(swatch.hex)
                            .font(BrandFont.mono(14, weight: .medium))
                        Image(systemName: copiedValue == swatch.hex ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(copiedValue == swatch.hex ? .green : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Sections

    private func insightSection(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(BrandFont.ui(15, weight: .bold))
            Text(body)
                .font(BrandFont.ui(15))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var conversions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Conversion")
                .font(BrandFont.ui(15, weight: .bold))
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                spacing: 8
            ) {
                ForEach(swatch.conversions) { conversion in
                    Button {
                        copy(conversion.value)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(conversion.label)
                                .font(BrandFont.ui(10, weight: .bold))
                                .foregroundStyle(.secondary)
                            Text(conversion.value)
                                .font(BrandFont.mono(11, weight: .medium))
                                .foregroundStyle(
                                    copiedValue == conversion.value ? .green : .primary
                                )
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 8)
                        .background(.primary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var harmonies: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Harmonies")
                .font(BrandFont.ui(15, weight: .bold))
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2),
                spacing: 8
            ) {
                ForEach(ColorHarmony.all(for: swatch)) { harmony in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(harmony.title)
                            .font(BrandFont.ui(12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        HStack(spacing: 5) {
                            ForEach(harmony.colors) { harmonyColor in
                                Button {
                                    copy(harmonyColor.hex)
                                } label: {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(harmonyColor.color)
                                        .frame(width: 26, height: 26)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 6)
                                                .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
                                        }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Copy \(harmonyColor.name), \(harmonyColor.hex)")
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
                    }
                }
            }
        }
    }

    private var accessibility: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Accessibility")
                .font(BrandFont.ui(15, weight: .bold))
            ForEach(swatch.accessibilityRows, id: \.label) { row in
                HStack {
                    Text(row.label)
                        .font(BrandFont.ui(15))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.2f:1", row.ratio))
                        .font(BrandFont.mono(12))
                        .foregroundStyle(.secondary)
                    Text(row.rating.label)
                        .font(BrandFont.ui(10, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(tint(for: row.rating.tone).opacity(0.15))
                        .foregroundStyle(tint(for: row.rating.tone))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var footnote: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(BrandColor.coral)
            Text("Tap any harmony swatch or conversion to copy it.")
                .font(BrandFont.ui(12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func tint(for tone: ContrastCalculator.Rating.Tone) -> Color {
        switch tone {
        case .good: return .green
        case .warning: return .orange
        case .bad: return .red
        }
    }

    private func copy(_ value: String) {
        UIPasteboard.general.string = value
        withAnimation(.easeOut(duration: 0.15)) { copiedValue = value }
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation(.easeOut(duration: 0.2)) {
                if copiedValue == value { copiedValue = nil }
            }
        }
    }
}

#Preview {
    ColorDetailView(swatch: PaletteColor(hex: 0x666770, dominance: 0.18))
}
