import SwiftUI
import ClerkKit

/// The effective plan comes from `GET /api/me`, while StoreKit supplies products and localized
/// prices. The backend verifies every transaction before this screen reports success.
struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var plan: String?
    @State private var state: LoadState = .loading
    @State private var productInfo: [ProProduct: ProProductInfo] = [:]
    @State private var selectedProduct: ProProduct = .annual
    @State private var activePurchase: ProProduct?
    @State private var isRestoring = false
    @State private var message: String?

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
    private var isBusy: Bool { activePurchase != nil || isRestoring }

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    switch state {
                    case .loading:
                        ProgressView("Loading your plans…")
                            .font(BrandFont.ui(14))
                            .frame(maxWidth: .infinity)
                            .padding(.top, 80)
                    case .failed(let error):
                        failureView(error)
                    case .loaded:
                        if isPaid { paidContent } else { offerContent }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Color(.systemBackground))
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await load() }
            .alert("ColorSense Pro", isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            )) {
                Button("OK", role: .cancel) { message = nil }
            } message: {
                Text(message ?? "")
            }
        }
    }

    private var offerContent: some View {
        VStack(spacing: 22) {
            SubscriptionHero(
                title: productInfo[.monthly]?.isEligibleForIntroOffer == true
                    ? "Meet your colors' full potential."
                    : "Make every color count.",
                detail: "Create, refine and export with every ColorSense Pro tool.",
                pose: .guiding
            )

            benefits

            VStack(spacing: 10) {
                ForEach(ProProduct.allCases, id: \.self) { product in
                    planChoice(product)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Choose a Pro plan")

            Button { purchase(selectedProduct) } label: {
                HStack(spacing: 9) {
                    if activePurchase == selectedProduct { ProgressView().tint(.white) }
                    Text(primaryActionTitle)
                }
            }
            .buttonStyle(.primaryAction)
            .disabled(productInfo[selectedProduct] == nil || isBusy)
            .opacity(productInfo[selectedProduct] == nil || isBusy ? 0.58 : 1)

            Text(selectedProduct == .pass
                 ? "One month of Pro. This purchase does not renew."
                 : "Subscription renews automatically until canceled.")
                .font(BrandFont.ui(12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            footer
        }
    }

    private var paidContent: some View {
        VStack(spacing: 22) {
            SubscriptionHero(
                title: "Your colors are ready to play.",
                detail: "Every Pro tool and export is active on this ColorSense account.",
                pose: .celebrating
            )

            VStack(spacing: 8) {
                Label("Current plan", systemImage: "sparkles")
                    .font(BrandFont.ui(12, weight: .bold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 9) {
                    Text(planLabel.uppercased()).font(BrandFont.display(46))
                    Text("ACTIVE")
                        .font(BrandFont.ui(10, weight: .bold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(BrandColor.yellow.opacity(0.35), in: Capsule())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))

            benefits

            Button { restore() } label: {
                HStack(spacing: 9) {
                    if isRestoring { ProgressView() }
                    Label("Restore Purchases", systemImage: "arrow.clockwise")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.secondaryAction)
            .disabled(isBusy)

            footer
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 13) {
            BenefitRow(
                title: "Export polished palettes and artwork",
                symbol: "square.and.arrow.up",
                color: BrandColor.coral
            )
            BenefitRow(
                title: "Use SVG Recolor, Visualizer and smart fixes",
                symbol: "wand.and.stars",
                color: BrandColor.purple
            )
            BenefitRow(
                title: "Keep the Extractor and WCAG checker free",
                symbol: "heart.fill",
                color: BrandColor.teal
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private func planChoice(_ product: ProProduct) -> some View {
        let selected = selectedProduct == product
        let accent = product.accent

        return Button { selectedProduct = product } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(accent)
                    .frame(width: 7)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text(product.title).font(BrandFont.ui(16, weight: .bold))
                        if product == .annual {
                            Text("POPULAR")
                                .font(BrandFont.ui(9, weight: .bold))
                                .foregroundStyle(PaletteColor(color: BrandColor.yellow).legibleForeground)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(BrandColor.yellow, in: Capsule())
                        }
                    }

                    Text(planDetail(for: product))
                        .font(BrandFont.ui(12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 6)

                VStack(alignment: .trailing, spacing: 7) {
                    Text(productInfo[product]?.displayPrice ?? "…")
                        .font(BrandFont.ui(17, weight: .bold))
                        .foregroundStyle(.primary)
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(selected ? accent : Color.secondary.opacity(0.45))
                }
            }
            .padding(.vertical, 13)
            .padding(.leading, 10)
            .padding(.trailing, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                selected ? accent.opacity(0.11) : Color(.secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: 17)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 17)
                    .stroke(selected ? accent : Color.clear, lineWidth: 2)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(productInfo[product] == nil || isBusy)
        .opacity(productInfo[product] == nil ? 0.6 : 1)
        .accessibilityLabel(planAccessibilityLabel(for: product, selected: selected))
    }

    private var primaryActionTitle: String {
        switch selectedProduct {
        case .monthly:
            return productInfo[.monthly]?.isEligibleForIntroOffer == true
                ? "Start 7-Day Free Trial"
                : "Choose Monthly"
        case .annual: return "Choose Annual"
        case .pass: return "Get Pro Pass"
        }
    }

    private func planDetail(for product: ProProduct) -> String {
        switch product {
        case .monthly:
            return productInfo[product]?.isEligibleForIntroOffer == true
                ? "7 days free, then renews monthly"
                : "Renews monthly until canceled"
        case .annual: return "A full year of Pro, billed yearly"
        case .pass: return "One month of Pro, no renewal"
        }
    }

    private func planAccessibilityLabel(for product: ProProduct, selected: Bool) -> String {
        let price = productInfo[product]?.displayPrice ?? "Price unavailable"
        return [product.title, price, planDetail(for: product), selected ? "Selected" : nil]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    private var footer: some View {
        VStack(spacing: 13) {
            if !isPaid {
                Button { restore() } label: {
                    HStack(spacing: 7) {
                        if isRestoring { ProgressView() }
                        Text("Restore Purchases")
                    }
                }
                .font(BrandFont.ui(14, weight: .medium))
                .disabled(isBusy)
            }

            HStack(spacing: 26) {
                Link("Terms", destination: URL(string: "https://colorsense.online/terms")!)
                Link("Privacy", destination: URL(string: "https://colorsense.online/privacy-policy")!)
            }
            .font(BrandFont.ui(13, weight: .medium))
        }
        .tint(.accentColor)
    }

    private func failureView(_ error: SavedPaletteService.SaveError) -> some View {
        VStack(spacing: 18) {
            SubscriptionHero(
                title: "The colors need a moment.",
                detail: error.message,
                pose: .unsure
            )
            if error.isRetryable {
                Button("Try Again") {
                    state = .loading
                    Task { await load() }
                }
                .buttonStyle(.primaryAction)
            }
        }
    }

    private func load() async {
        switch await SavedPaletteService.currentPlan() {
        case .success(let value):
            plan = value
            state = .loaded

            // A paid account has no product chooser, so waiting for Apple's catalog only delays
            // the active-plan screen. Free accounts render immediately with price placeholders,
            // then enable each choice as StoreKit supplies its localized product information.
            if value != "pro" && value != "business" {
                productInfo = await ProStoreRegistry.current.productInfo()
            }
        case .failure(let error):
            state = .failed(error)
        }
    }

    private func purchase(_ product: ProProduct) {
        activePurchase = product
        Task {
            let outcome = await ProStoreRegistry.current.purchase(product)
            activePurchase = nil
            switch outcome {
            case .purchased:
                message = "Your purchase is active."
                await load()
            case .cancelled: break
            case .pending:
                message = "The purchase is waiting for approval. Pro will activate after the App Store completes it."
            case .notConfigured:
                message = "In-app purchases are not available yet."
            case .failed(let error):
                message = error
            }
        }
    }

    private func restore() {
        isRestoring = true
        Task {
            let outcome = await ProStoreRegistry.current.restore()
            isRestoring = false
            switch outcome {
            case .purchased:
                message = "Your purchase was restored."
                await load()
            case .cancelled: break
            case .pending:
                message = "The purchase is still pending."
            case .notConfigured:
                message = "Restore Purchases is not available yet."
            case .failed(let error):
                message = error
            }
        }
    }
}

private struct SubscriptionHero: View {
    let title: String
    let detail: String
    let pose: LaumaPose

    @ScaledMetric(relativeTo: .largeTitle) private var mascotHeight: CGFloat = 116

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            BrandColor.yellow.opacity(0.62),
                            BrandColor.teal.opacity(0.42),
                            BrandColor.purple.opacity(0.30),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            HeroColorConfetti()

            VStack(spacing: 8) {
                LaumaStage(pose: pose, height: min(mascotHeight, 154))
                    .accessibilityHidden(true)

                Text(title)
                    .font(BrandFont.display(36))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(detail)
                    .font(BrandFont.ui(14))
                    .foregroundStyle(.primary.opacity(0.76))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 290)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .accessibilityElement(children: .combine)
    }
}

private struct HeroColorConfetti: View {
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // The chips sit at fixed fractions of the hero, so they do not move as the hero grows with
        // the type inside it. At accessibility sizes the headline and paragraph expand into the
        // corners the chips occupy and the decoration lands on the words: measured at
        // accessibility-extra-large, the teal chip covered the first character of "Create, refine
        // and export" and the yellow one sat inside the same paragraph.
        //
        // The decoration yields rather than being repositioned, because there is no fixed position
        // that stays clear at every size, and a reader at accessibility sizes is asking for words
        // rather than confetti. The hero keeps its gradient and Lauma, so nothing reads as missing.
        if !typeSize.isAccessibilitySize {
            chips
        }
    }

    private var chips: some View {
        GeometryReader { proxy in
            Group {
                chip(BrandColor.coral, width: 54, height: 22, angle: -14)
                    .position(x: proxy.size.width * 0.13, y: proxy.size.height * 0.18)
                chip(BrandColor.purple, width: 42, height: 18, angle: 18)
                    .position(x: proxy.size.width * 0.86, y: proxy.size.height * 0.22)
                chip(BrandColor.teal, width: 50, height: 20, angle: 12)
                    .position(x: proxy.size.width * 0.12, y: proxy.size.height * 0.76)
                chip(BrandColor.yellow, width: 46, height: 18, angle: -20)
                    .position(x: proxy.size.width * 0.88, y: proxy.size.height * 0.73)
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private func chip(_ color: Color, width: CGFloat, height: CGFloat, angle: Double) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(color.opacity(0.78))
            .frame(width: width, height: height)
            .overlay {
                RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.55), lineWidth: 1)
            }
            .rotationEffect(.degrees(angle))
    }
}

private struct BenefitRow: View {
    let title: String
    let symbol: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(PaletteColor(color: color).legibleForeground)
                .frame(width: 30, height: 30)
                .background(color, in: Circle())
                .accessibilityHidden(true)
            Text(title)
                .font(BrandFont.ui(15, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private extension ProProduct {
    var accent: Color {
        switch self {
        case .monthly: BrandColor.teal
        case .annual: BrandColor.purple
        case .pass: BrandColor.coral
        }
    }
}
