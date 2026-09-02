import SwiftUI

/// Shows what a fix would change, and lets the reader decide.
///
/// Deliberately not automatic. Both "Fix it" and the health report's auto-remap alter a colour
/// somebody chose — often a brand colour — so applying one silently would be the app overruling
/// its user on the thing the whole product is about. Tapping proposes; the reader disposes.
///
/// Takes a list rather than a single proposal because the health report can have several failing
/// pairings at once, and which of them to correct is a judgement the reader should make one at a
/// time. The Contrast tool passes a list of one.
struct ContrastFixSheet: View {
    struct Proposal: Identifiable {
        let id: Int
        /// What is wrong, in plain words — shown before the remedy.
        let problem: String
        /// The colour being changed.
        let original: PaletteColor
        let proposed: PaletteColor
        /// The colour it is measured against, for the preview.
        let against: PaletteColor
        /// True when the anchor sits *behind* the changing colour, so the preview paints the
        /// right one as the surface.
        let changingIsForeground: Bool
        let currentRatio: Double
        let newRatio: Double
        let wentLighter: Bool
    }

    let title: String
    var isPro = true
    let proposals: [Proposal]
    let onApply: (Proposal) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var applied: Set<Int> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !isPro { proNotice }

                    Text(proposals.count == 1
                         ? "Here's what's failing and how to fix it. Nothing changes until you say so."
                         : "\(proposals.count) pairings are failing. Fix the ones you want — nothing changes until you say so.")
                        .font(BrandFont.ui(14))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(proposals) { proposal in
                        card(proposal)
                    }
                }
                .padding(20)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func card(_ proposal: Proposal) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(proposal.problem)
                .font(BrandFont.ui(14, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)

            // Before and after, measured the same way, side by side — the only honest way to
            // show a contrast change is to show both.
            HStack(spacing: 10) {
                preview(
                    swatch: proposal.original,
                    against: proposal.against,
                    changingIsForeground: proposal.changingIsForeground,
                    caption: "Now",
                    ratio: proposal.currentRatio,
                    tone: .secondary
                )
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                preview(
                    swatch: proposal.proposed,
                    against: proposal.against,
                    changingIsForeground: proposal.changingIsForeground,
                    caption: proposal.wentLighter ? "Lighter" : "Darker",
                    ratio: proposal.newRatio,
                    tone: BrandColor.coral
                )
            }

            HStack(spacing: 6) {
                Text(proposal.original.hex)
                    .brandMono(12)
                    .foregroundStyle(.secondary)
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(proposal.proposed.hex)
                    .brandMono(12, weight: .bold)
                Text("· \(proposal.proposed.name)")
                    .font(BrandFont.ui(12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Button {
                guard isPro else { return }
                onApply(proposal)
                applied.insert(proposal.id)
            } label: {
                Label(
                    !isPro
                        ? "Applying is part of Pro"
                        : applied.contains(proposal.id) ? "Applied" : "Apply this fix",
                    systemImage: !isPro
                        ? "lock.fill"
                        : applied.contains(proposal.id) ? "checkmark.circle.fill" : "wand.and.stars"
                )
                .font(BrandFont.ui(15, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .disabled(!isPro || applied.contains(proposal.id))
            .foregroundStyle(!isPro || applied.contains(proposal.id) ? BrandColor.coral : .white)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(!isPro || applied.contains(proposal.id)
                          ? BrandColor.coral.opacity(0.12)
                          : BrandColor.coral)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    /// Names Pro and stops there, deliberately.
    ///
    /// There is no "upgrade" button and no link, because there is nothing legitimate to link to:
    /// the app has no StoreKit, and App Store guideline 3.1.1 forbids sending people to an
    /// outside purchase — the same rule that removed "Pro is available at colorsense.online" from
    /// the Subscription screen. Until in-app purchase exists, the honest move is to show the
    /// value in full and say what unlocks it. The fix itself is shown, measured, and named above,
    /// so nothing is hidden except the one tap that applies it.
    private var proNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(BrandColor.purple)
            VStack(alignment: .leading, spacing: 3) {
                Text("Applying fixes is a Pro feature")
                    .font(BrandFont.ui(14, weight: .bold))
                Text("You can see exactly what it would change below, and the new hex, so you can make the change by hand if you'd rather.")
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

    private func preview(
        swatch: PaletteColor,
        against: PaletteColor,
        changingIsForeground: Bool,
        caption: String,
        ratio: Double,
        tone: Color
    ) -> some View {
        VStack(spacing: 5) {
            Text("Aa")
                .font(BrandFont.ui(19, weight: .bold))
                .foregroundStyle(changingIsForeground ? swatch.color : against.color)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(changingIsForeground ? against.color : swatch.color)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text(String(format: "%.2f:1", ratio))
                .brandMono(12, weight: .bold)
                .foregroundStyle(tone)
            Text(caption)
                .font(BrandFont.ui(10, weight: .bold))
                .foregroundStyle(.secondary)
        }
    }
}
