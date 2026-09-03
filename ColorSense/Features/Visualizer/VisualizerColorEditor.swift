import SwiftUI

/// Changing one palette colour from inside the Visualizer.
///
/// Deliberately thin: it is the app's shared `CustomColorEditor` with a confirm, so entering a
/// colour here behaves exactly as it does in the swatch editor and in SVG Recolor. Nothing about
/// picking a colour should depend on which screen you happen to be standing on.
struct VisualizerColorEditor: View {
    let swatch: PaletteColor
    let onApply: (PaletteColor) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var color: Color
    @State private var isValid = true

    init(swatch: PaletteColor, onApply: @escaping (PaletteColor) -> Void) {
        self.swatch = swatch
        self.onApply = onApply
        _color = State(initialValue: swatch.color)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(color)
                    .frame(height: 96)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.12), lineWidth: 1)
                    }

                CustomColorEditor(color: $color, isValid: $isValid)

                Button("Use this color") {
                    // Dominance is carried over rather than recomputed: it describes how much of the
                    // original photo this slot covered, and changing the colour does not change that.
                    onApply(PaletteColor(color: color, dominance: swatch.dominance))
                    dismiss()
                }
                .buttonStyle(.primaryAction)
                .disabled(!isValid)
                .opacity(isValid ? 1 : 0.55)

                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle("Change color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
