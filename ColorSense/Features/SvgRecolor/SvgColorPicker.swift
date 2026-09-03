import SwiftUI

/// Choosing what one colour in the SVG becomes.
///
/// This exists because the first version put every choice inline: each found colour carried its own
/// strip of palette swatches, so a five-colour file repeated the same five circles five times and
/// the screen became a wall of dots with no clear reading order. Moving the choice into a sheet
/// leaves one compact row per colour, and gives the arbitrary-colour option somewhere to live.
///
/// The palette comes first because it is the reason the tool exists. A free colour is offered
/// underneath, through the same `CustomColorEditor` the swatch editor uses, rather than a second
/// hex field that would behave subtly differently.
struct SvgColorPicker: View {
    let original: String
    let palette: [PaletteColor]
    @Binding var target: String

    @Environment(\.dismiss) private var dismiss

    @State private var customColor: Color = .gray
    @State private var customIsValid = true

    private let columns = [GridItem(.adaptive(minimum: 64), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    comparison

                    section("From this palette") {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(palette) { swatch in
                                choice(hex: swatch.hex.lowercased(), name: swatch.name)
                            }
                        }
                    }

                    section("Any color") {
                        VStack(alignment: .leading, spacing: 10) {
                            CustomColorEditor(color: $customColor, isValid: $customIsValid)
                            Button("Use this color") {
                                target = PaletteColor(color: customColor).hex.lowercased()
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(BrandColor.coral)
                            .disabled(!customIsValid)
                            .opacity(customIsValid ? 1 : 0.55)
                        }
                    }

                    Button("Put the original colour back") {
                        target = original
                        dismiss()
                    }
                    .font(BrandFont.ui(15, weight: .medium))
                    .frame(maxWidth: .infinity)
                }
                .padding(20)
            }
            .navigationTitle("Replace \(original)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.large, .medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            customColor = PaletteColor(hexString: target, dominance: 0)?.color ?? .gray
        }
    }

    private var comparison: some View {
        HStack(spacing: 14) {
            labelled(hex: original, caption: "In the file")
            Image(systemName: "arrow.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)
            labelled(hex: target, caption: "Becomes")
            Spacer(minLength: 0)
        }
    }

    private func labelled(hex: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            RoundedRectangle(cornerRadius: 10)
                .fill(PaletteColor(hexString: hex, dominance: 0)?.color ?? .clear)
                .frame(width: 62, height: 44)
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                }
            Text(hex).brandMono(11, weight: .regular).foregroundStyle(.secondary)
            Text(caption).font(BrandFont.ui(11)).foregroundStyle(.tertiary)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(BrandFont.ui(12, weight: .bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content()
        }
    }

    private func choice(hex: String, name: String) -> some View {
        let isChosen = target.caseInsensitiveCompare(hex) == .orderedSame
        return Button {
            target = hex
            dismiss()
        } label: {
            VStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(PaletteColor(hexString: hex, dominance: 0)?.color ?? .clear)
                    .frame(height: 52)
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isChosen ? BrandColor.coral : Color.primary.opacity(0.15),
                                    lineWidth: isChosen ? 3 : 1)
                    }
                Text(hex).brandMono(10, weight: .regular).foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(name), \(hex)")
        .accessibilityAddTraits(isChosen ? [.isSelected] : [])
    }
}

/// The colour currently being reassigned.
///
/// A tiny wrapper rather than conforming `String` to `Identifiable`. That conformance would be
/// retroactive, app-wide, and would silently change how every `ForEach` over strings behaves; it is
/// not worth it to save a struct.
struct EditingSvgColor: Identifiable {
    let id: String
}
