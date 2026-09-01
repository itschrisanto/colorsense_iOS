import SwiftUI

/// Affiliate programme details, matching the terms on the web app's Account page. Applying opens
/// colorsense.online/affiliate in the browser — this is a referral partnership, not a digital
/// good sold to the user, so linking out is fine where a Pro checkout link would not be.
struct AffiliateView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Image(systemName: "hands.clap.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(BrandColor.coral)

                    Text("Refer ColorSense, earn cash")
                        .font(BrandFont.ui(19, weight: .bold))

                    Text("30% one-time bounty on every paid signup. 30-day cookie. $100 minimum payout via Lemon Squeezy. Apply and we'll review within a few days.")
                        .font(BrandFont.ui(15))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Link(destination: URL(string: "https://colorsense.online/affiliate")!) {
                        Text("Apply on colorsense.online")
                            .font(BrandFont.ui(16, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(BrandColor.coral)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .navigationTitle("Affiliate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }
}
