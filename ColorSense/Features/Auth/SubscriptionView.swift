import SwiftUI
import ClerkKit

/// Current plan, read from `GET /api/me` — the same endpoint the web app's `usePlan` uses, which
/// computes the effective plan at read time so trial and voucher grants expire on their own.
///
/// Deliberately read-only: there is **no** upgrade or checkout link. App Store guideline 3.1.1
/// requires digital-goods purchases to go through In-App Purchase, and routing users to the web
/// checkout instead is a common rejection cause. Selling Pro from inside the app means StoreKit,
/// which is a separate piece of work — until then this reports status and nothing more.
struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var plan: String?
    @State private var state: LoadState = .loading

    private enum LoadState: Equatable {
        case loading, loaded, failed(String)
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
                    case .failed(let message):
                        Text(message)
                            .font(BrandFont.ui(15))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    case .loaded:
                        planCard
                        Text(isPaid
                             ? "Manage or cancel your plan at colorsense.online."
                             : "Pro is available at colorsense.online.")
                            .font(BrandFont.ui(13))
                            .foregroundStyle(.secondary)
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
            state = .failed(error.message)
        }
    }
}
