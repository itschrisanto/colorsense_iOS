import SwiftUI
import ClerkKit

/// Current plan, read from `GET /api/me` — the same endpoint the web app's `usePlan` uses, which
/// computes the effective plan at read time so trial and voucher grants expire on their own.
///
/// Deliberately read-only: there is **no** upgrade or checkout link, and no mention of where one
/// lives. App Store guideline 3.1.1 requires digital-goods purchases to go through In-App
/// Purchase, and it covers prose as well as buttons — "Pro is available at colorsense.online"
/// was still a call to action pointing at an external purchase mechanism, so it is gone. Selling
/// Pro from inside the app means StoreKit, which is a separate piece of work — until then this
/// reports status and nothing more.
struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var plan: String?
    @State private var state: LoadState = .loading

    private enum LoadState: Equatable {
        case loading, loaded, failed(SavedPaletteService.SaveError)
    }

    private var planLabel: String {
        switch plan {
        case "pro": return "Pro"
        case "business": return "Business"
        default: return "Free"
        }
    }

    private var isPaid: Bool { plan == "pro" || plan == "business" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch state {
                    case .loading:
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                    case .failed(let error):
                        // Every other loading screen offers a retry; this one left closing and
                        // reopening the sheet as the only way to try again. Gated the same way
                        // they are — see SaveError.isRetryable.
                        VStack(alignment: .leading, spacing: 12) {
                            Text(error.message)
                                .font(BrandFont.ui(15))
                                .foregroundStyle(.secondary)
                            if error.isRetryable {
                                Button("Try again") {
                                    state = .loading
                                    Task { await load() }
                                }
                                .font(BrandFont.ui(15, weight: .medium))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    case .loaded:
                        planCard
                        // Neither branch names the web checkout. A paid user still needs to
                        // learn that cancelling does not happen here, so that is stated without
                        // pointing at where it does; a free user gets the tier described rather
                        // than a route to buy it. See the 3.1.1 note above.
                        Text(isPaid
                             ? "Your plan is managed outside the app."
                             : "Pro unlocks the developer and design export formats.")
                            .font(BrandFont.ui(13))
                            .foregroundStyle(.secondary)

                        plans
                    }
                }
                .padding(20)
            }
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .task { await load() }
        }
    }

    /// Every plan ColorSense sells, listed so the shapes exist before In-App Purchase does.
    ///
    /// **Descriptive, not a shop.** Nothing here is tappable and nothing says where to buy: with no
    /// StoreKit yet, a button would either do nothing or point outside the app, and guideline 3.1.1
    /// forbids the second in prose as much as in buttons. When `ProStore` goes live these rows are
    /// where the buy actions attach, which is the point of listing them now.
    ///
    /// Prices come from `ProProduct`, which reads them off the vault, so this screen cannot drift
    /// from the onboarding plan beat or from the web.
    private var plans: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What ColorSense offers")
                .font(BrandFont.ui(13, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            planRow(
                title: "Free",
                price: "$0",
                detail: "The Extractor and the WCAG checker, unlimited and never paywalled.",
                isCurrent: !isPaid
            )

            ForEach(ProProduct.allCases, id: \.self) { product in
                planRow(
                    title: product.title,
                    price: product.price,
                    detail: product.detail,
                    // The server reports one effective plan, not which product bought it, so a
                    // paid reader cannot be told *which* of these three they are on. Saying
                    // nothing is better than guessing wrong at somebody's own subscription.
                    isCurrent: false
                )
            }

            Text("In-app purchase is not available yet, so these are listed rather than offered.")
                .font(BrandFont.ui(12))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
    }

    private func planRow(title: String, price: String, detail: String, isCurrent: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(title).font(BrandFont.ui(15, weight: .bold))
                    if isCurrent {
                        Text("CURRENT")
                            .font(BrandFont.ui(10, weight: .bold))
                            .foregroundStyle(PaletteColor(color: BrandColor.teal).legibleForeground)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(BrandColor.teal, in: Capsule())
                    }
                }
                Text(detail)
                    .font(BrandFont.ui(13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Text(price).font(BrandFont.ui(16, weight: .bold))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Current plan", systemImage: "sparkles")
                .font(BrandFont.ui(11, weight: .bold))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Text(planLabel)
                    .font(BrandFont.display(34))
                if isPaid {
                    Text("ACTIVE")
                        .font(BrandFont.ui(10, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(BrandColor.yellow.opacity(0.25))
                        .foregroundStyle(.primary)
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func load() async {
        switch await SavedPaletteService.currentPlan() {
        case .success(let value):
            plan = value
            state = .loaded
        case .failure(let error):
            state = .failed(error)
        }
    }
}
