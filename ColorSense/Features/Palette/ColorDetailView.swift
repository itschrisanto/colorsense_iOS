import SwiftUI

/// The color detail card, mirroring the web app's `ColorDetailCard.tsx`: insights, conversions,
/// harmonies and accessibility, all computed on-device and free — matching the brand stance that
/// these are not gated. The web's "Generate Harmonies · AI · Pro" button is deliberately absent
/// (no StoreKit on iOS yet — see CLAUDE.md).
struct ColorDetailView: View {
    let isPro: Bool
    let swatch: PaletteColor

    @Environment(\.dismiss) private var dismiss
    @State private var copiedValue: String?
    @State private var saveColorIsPresented = false
    @State private var savedColorName: String?

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
                        saveColorButton
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
        .sheet(isPresented: $saveColorIsPresented) {
            SaveColorView(swatch: swatch, isPro: isPro) { name in
                savedColorName = name
            }
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
                            .brandMono(14, weight: .medium)
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
                                .brandMono(11, weight: .medium)
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
                        .brandMono(12)
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

    private var saveColorButton: some View {
        Button {
            saveColorIsPresented = true
        } label: {
            Label(
                savedColorName.map { "Saved as \($0)" } ?? "Save color to my account",
                systemImage: savedColorName == nil ? "bookmark" : "checkmark.circle.fill"
            )
            .font(BrandFont.ui(15, weight: .medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .foregroundStyle(savedColorName == nil ? .white : BrandColor.coral)
        .background {
            RoundedRectangle(cornerRadius: 13)
                .fill(savedColorName == nil ? BrandColor.coral : BrandColor.coral.opacity(0.12))
        }
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

private struct SaveColorView: View {
    let swatch: PaletteColor
    /// Pro removes the free account's saved-color limit.
    let isPro: Bool
    let onSaved: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var nameIsFocused: Bool
    @State private var savedCount: Int?

    init(swatch: PaletteColor, isPro: Bool, onSaved: @escaping (String) -> Void) {
        self.swatch = swatch
        self.isPro = isPro
        self.onSaved = onSaved
        _name = State(initialValue: swatch.customName ?? swatch.name)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(swatch.color)
                        .frame(width: 72, height: 72)
                        .overlay {
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
                        }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(swatch.hex)
                            .brandMono(15, weight: .medium)
                        Text("Give this color a name you will recognize later.")
                            .font(BrandFont.ui(13))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }

                TextField("Color name", text: $name)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .focused($nameIsFocused)
                    .padding(.horizontal, 14)
                    .frame(height: 50)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    .onSubmit { save() }

                if isAtLimit {
                    LaumaNotice(
                        pose: .unsure,
                        title: "Your saved colors are full",
                        message: "A free account holds \(SavedPaletteService.Allowance.colors) saved colors. Delete one to make room, or Pro removes the limit."
                    )
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(BrandFont.ui(13))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    save()
                } label: {
                    Group {
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Label("Save color", systemImage: "bookmark")
                        }
                    }
                }
                .buttonStyle(.primaryAction)
                .disabled(isSaving || trimmedName.isEmpty || isAtLimit)
                .opacity(trimmedName.isEmpty ? 0.55 : 1)

                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle("Save color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                nameIsFocused = true
                if !isPro { savedCount = await SavedPaletteService.savedColorCount() }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Nil means unknown, and unknown never blocks: refusing to save because a count would not
    /// load is a worse failure than letting the server decide.
    private var isAtLimit: Bool {
        guard !isPro, let savedCount else { return false }
        return savedCount >= SavedPaletteService.Allowance.colors
    }

    private func save() {
        guard !isAtLimit else { return }
        guard !isSaving, !trimmedName.isEmpty else { return }
        isSaving = true
        errorMessage = nil
        Task {
            switch await SavedPaletteService.save(swatch, name: trimmedName) {
            case .success:
                onSaved(trimmedName)
                dismiss()
            case .failure(.notSignedIn):
                errorMessage = "Sign in from Account to save this color."
                isSaving = false
            case .failure(let error):
                errorMessage = error.message
                isSaving = false
            }
        }
    }
}

#Preview {
    ColorDetailView(isPro: false, swatch: PaletteColor(hex: 0x666770, dominance: 0.18))
}
