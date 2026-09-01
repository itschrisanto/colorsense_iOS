import SwiftUI

/// The palette rendered as full-bleed bands splitting the available height, matching the web
/// app's mobile layout. Tapping a band opens its detail card; the lock button keeps a swatch
/// through Generate.
struct PaletteBandsView: View {
    let palette: ExtractedPalette
    let onToggleLock: (PaletteColor.ID) -> Void
    let onOpenDetail: (PaletteColor) -> Void

    /// Hex of the swatch most recently copied, so its button can confirm with a checkmark.
    @State private var copiedHex: String?

    var body: some View {
        VStack(spacing: 0) {
            ForEach(palette.colors) { swatch in
                band(swatch)
            }
        }
    }

    private func band(_ swatch: PaletteColor) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(swatch.hex)
                    .font(BrandFont.mono(26))
                Text(swatch.name)
                    .font(BrandFont.ui(15))
                    .opacity(0.75)
            }
            Spacer()

            Button {
                copy(swatch)
            } label: {
                Image(systemName: copiedHex == swatch.hex ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 17))
                    .opacity(copiedHex == swatch.hex ? 1 : 0.55)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Copy \(swatch.hex)")

            Button {
                onToggleLock(swatch.id)
            } label: {
                Image(systemName: swatch.isLocked ? "lock.fill" : "lock.open")
                    .font(.system(size: 17))
                    .opacity(swatch.isLocked ? 1 : 0.55)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(swatch.isLocked ? "Unlock \(swatch.name)" : "Lock \(swatch.name)")
        }
        .foregroundStyle(swatch.legibleForeground)
        .padding(.leading, 20)
        .padding(.trailing, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(swatch.color)
        // A tap gesture rather than wrapping the row in a Button, so the lock button inside
        // stays independently tappable.
        .contentShape(.rect)
        .onTapGesture { onOpenDetail(swatch) }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Show color details") { onOpenDetail(swatch) }
    }

    private func copy(_ swatch: PaletteColor) {
        UIPasteboard.general.string = swatch.hex
        withAnimation(.easeOut(duration: 0.15)) { copiedHex = swatch.hex }
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation(.easeOut(duration: 0.2)) {
                if copiedHex == swatch.hex { copiedHex = nil }
            }
        }
    }
}

#Preview {
    PaletteBandsView(palette: .sample, onToggleLock: { _ in }, onOpenDetail: { _ in })
}
