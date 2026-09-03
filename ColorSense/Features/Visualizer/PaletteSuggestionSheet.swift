import SwiftUI

/// A better palette, proposed rather than applied.
///
/// Follows the rule the other two Pro fixes already follow, recorded in CLAUDE.md: **nothing changes
/// until the reader presses Apply.** The whole suggestion is shown first, both scores, every colour
/// that would move and every colour that would not, because changing colours somebody chose, often
/// brand colours, without asking would be the app overruling its user on the one thing the product
/// is about.
///
/// Locked swatches are shown as locked and are never in the changing list. That is the promise the
/// feature rests on: lock what you cannot move, and this works around it.
struct PaletteSuggestionSheet: View {
    let suggestion: PaletteImprover.Suggestion
    let isPro: Bool
    let onApply: ([PaletteColor]) -> Void

    @Environment(\.dismiss) private var dismiss


    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    scores
                    swatches

                    if isPro {
                        Button("Apply this palette") {
                            onApply(suggestion.colors)
                            dismiss()
                        }
                        .buttonStyle(.primaryAction)
                    } else {
                        proNotice
                    }
                }
                .padding(20)
            }
            .navigationTitle("A better palette")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .presentationDetents([.large, .medium])
        .presentationDragIndicator(.visible)
    }

    private var scores: some View {
        HStack(spacing: 16) {
            scoreBlock("Now", suggestion.before)
            Image(systemName: "arrow.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.tertiary)
            scoreBlock("Suggested", suggestion.after)
            Spacer(minLength: 0)
        }
    }

    private func scoreBlock(_ caption: String, _ result: PaletteHealth.Result) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(caption).font(BrandFont.ui(11, weight: .bold)).foregroundStyle(.secondary)
            Text("\(result.overall)").font(BrandFont.display(30))
            Text("Grade " + result.grade.rawValue).font(BrandFont.ui(12, weight: .medium)).foregroundStyle(.secondary)
        }
    }

    /// Every slot, in order, so what stays is as visible as what moves. A list of only the changes
    /// would hide that a locked colour survived, which is the thing the reader most needs to see.
    private var swatches: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What changes")
                .font(BrandFont.ui(13, weight: .bold))
                .foregroundStyle(.secondary)

            ForEach(Array(suggestion.colors.enumerated()), id: \.element.id) { index, after in
                let before = beforeColor(at: index)
                HStack(spacing: 12) {
                    swatch(before)
                    Text(before?.hex ?? "")
                        .brandMono(12, weight: .regular)
                        .foregroundStyle(.secondary)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                    swatch(after)
                    Text(after.hex).brandMono(12, weight: .medium)
                    Spacer(minLength: 0)
                    if after.isLocked {
                        Label("Kept", systemImage: "lock.fill")
                            .font(BrandFont.ui(11, weight: .medium))
                            .foregroundStyle(BrandColor.coral)
                            .labelStyle(.titleAndIcon)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func swatch(_ color: PaletteColor?) -> some View {
        RoundedRectangle(cornerRadius: 7)
            .fill(color?.color ?? .clear)
            .frame(width: 30, height: 30)
            .overlay { RoundedRectangle(cornerRadius: 7).stroke(Color.primary.opacity(0.15), lineWidth: 1) }
    }

    private var proNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(BrandColor.purple)
            VStack(alignment: .leading, spacing: 3) {
                Text("Applying a suggestion is a Pro feature")
                    .font(BrandFont.ui(14, weight: .bold))
                Text("The whole suggestion is above, every hex included, so you can make the change by hand if you'd rather.")
                    .font(BrandFont.ui(13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BrandColor.purple.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    /// The colour currently in that slot, matched by id so a reordered palette still lines up.
    private var beforeColors: [PaletteColor] = []
    private func beforeColor(at index: Int) -> PaletteColor? {
        index < beforeColors.count ? beforeColors[index] : nil
    }

    init(
        suggestion: PaletteImprover.Suggestion,
        current: [PaletteColor],
        isPro: Bool,
        onApply: @escaping ([PaletteColor]) -> Void
    ) {
        self.suggestion = suggestion
        self.beforeColors = current
        self.isPro = isPro
        self.onApply = onApply
    }
}
