import SwiftUI

/// Picking an arbitrary colour: the system wheel and sliders, plus a validated, paste-aware
/// six-digit hex field.
///
/// Extracted from `AddColorView`, which owned the only copy. It is shared rather than duplicated so
/// that entering a colour works the same way everywhere in the app: the same field, the same
/// filtering, the same message when the clipboard holds something that is not a colour. A second
/// implementation would drift, and this one has already accumulated behaviour worth keeping.
///
/// The bound `color` is only written when the text parses, so a caller never sees a colour from a
/// half-typed hex. `isValid` reports whether what is currently typed is a colour, which is what a
/// confirm button should be gated on.
struct CustomColorEditor: View {
    @Binding var color: Color
    @Binding var isValid: Bool

    @State private var digits: String
    @State private var error: String?
    @FocusState private var fieldIsFocused: Bool

    init(color: Binding<Color>, isValid: Binding<Bool>) {
        _color = color
        _isValid = isValid
        _digits = State(initialValue: String(PaletteColor(color: color.wrappedValue).hex.dropFirst()))
    }

    var body: some View {
        VStack(spacing: 0) {
            ColorPicker(selection: $color, supportsOpacity: false) {
                Label("Color wheel and sliders", systemImage: "paintpalette")
                    .font(BrandFont.ui(14, weight: .medium))
            }
            .padding(.horizontal, 12)
            .frame(height: 48)
            .onChange(of: color) { _, value in
                let updated = String(PaletteColor(color: value).hex.dropFirst())
                if digits != updated { digits = updated }
                error = nil
                isValid = true
            }

            Divider().padding(.leading, 12)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text("#")
                        .brandMono(15, weight: .medium)
                        .foregroundStyle(.secondary)
                    TextField("RRGGBB", text: $digits)
                        .brandMono(15, weight: .medium)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        .submitLabel(.done)
                        .focused($fieldIsFocused)
                        .onChange(of: digits) { _, value in applyTyped(value) }

                    PasteButton(payloadType: String.self) { values in
                        if let value = values.first { applyPasted(value) }
                    }
                    .labelStyle(.titleAndIcon)
                    .tint(BrandColor.coral)
                }

                if let error {
                    Text(error)
                        .font(BrandFont.ui(11))
                        .foregroundStyle(.red)
                } else {
                    Text("Type or paste a six-digit hex value.")
                        .font(BrandFont.ui(11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.primary.opacity(0.08), lineWidth: 0.5)
        }
    }

    /// Filters as you type: a leading `#` or `0x` is dropped, non-hex characters never appear, and
    /// the field stops at six digits rather than letting a seventh silently do nothing.
    private func applyTyped(_ value: String) {
        var candidate = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if candidate.hasPrefix("#") {
            candidate.removeFirst()
        } else if candidate.hasPrefix("0X") {
            candidate.removeFirst(2)
        }
        let filtered = String(candidate.filter(\.isHexDigit).prefix(6))
        if filtered != value {
            digits = filtered
            return
        }

        guard let swatch = PaletteColor(hexString: filtered, dominance: 0) else {
            // Only complain about a complete value. Half a hex is not yet wrong.
            error = filtered.count == 6 ? "Enter a valid hex color." : nil
            isValid = false
            return
        }
        color = swatch.color
        error = nil
        isValid = true
    }

    private func applyPasted(_ value: String) {
        guard let swatch = PaletteColor(hexString: value, dominance: 0) else {
            error = "That clipboard value is not a six-digit hex color."
            isValid = false
            return
        }
        digits = String(swatch.hex.dropFirst())
        color = swatch.color
        error = nil
        isValid = true
    }
}
