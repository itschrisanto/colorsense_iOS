import Foundation
import StoreKit

/// The App Store products, kept in one place so the client and App Store Connect cannot drift.
enum ProProduct: String, CaseIterable, Sendable {
    case monthly = "online.colorsense.ios.pro.monthly"
    case annual = "online.colorsense.ios.pro.annual"
    case pass = "online.colorsense.ios.pro.pass"

    enum Kind: Equatable, Sendable { case autoRenewable, consumable }

    var kind: Kind {
        switch self {
        case .monthly, .annual: return .autoRenewable
        case .pass: return .consumable
        }
    }

    var title: String {
        switch self {
        case .monthly: return "Pro Monthly"
        case .annual: return "Pro Annual"
        case .pass: return "Pro Pass"
        }
    }
}

/// Storefront-specific information. Prices always come from StoreKit, never hardcoded USD copy.
struct ProProductInfo: Equatable, Sendable {
    let product: ProProduct
    let displayPrice: String
    let isEligibleForIntroOffer: Bool
}

enum PurchaseOutcome: Equatable, Sendable {
    case purchased
    case cancelled
    case pending
    case notConfigured
    case failed(String)
}

protocol ProStore: Sendable {
    var isLive: Bool { get }
    func start() async
    func productInfo() async -> [ProProduct: ProProductInfo]
    func purchase(_ product: ProProduct) async -> PurchaseOutcome
    func restore() async -> PurchaseOutcome
}

struct PlaceholderProStore: ProStore {
    var isLive: Bool { false }
    func start() async {}
    func productInfo() async -> [ProProduct: ProProductInfo] { [:] }
    func purchase(_ product: ProProduct) async -> PurchaseOutcome { .notConfigured }
    func restore() async -> PurchaseOutcome { .notConfigured }
}

/// StoreKit 2 purchase handling. A transaction is finished only after the authenticated backend
/// verifies Apple's JWS and `/api/me` reports the paid entitlement. If delivery fails, StoreKit
/// keeps the transaction unfinished and `start()` retries it on the next launch.
actor StoreKitProStore: ProStore {
    nonisolated let isLive = true

    private var productsByID: [String: Product] = [:]
    private var updatesTask: Task<Void, Never>?
    private let hasAuthenticatedSession: @Sendable () async -> Bool
    private let syncAppStore: @Sendable () async throws -> Void
    private let fetchCurrentPlan: @Sendable () async -> Result<String?, SavedPaletteService.SaveError>

    init(
        hasAuthenticatedSession: @escaping @Sendable () async -> Bool = {
            await SavedPaletteService.hasAuthenticatedSession()
        },
        syncAppStore: @escaping @Sendable () async throws -> Void = {
            try await AppStore.sync()
        },
        fetchCurrentPlan: @escaping @Sendable () async -> Result<String?, SavedPaletteService.SaveError> = {
            await SavedPaletteService.currentPlan()
        }
    ) {
        self.hasAuthenticatedSession = hasAuthenticatedSession
        self.syncAppStore = syncAppStore
        self.fetchCurrentPlan = fetchCurrentPlan
    }

    deinit { updatesTask?.cancel() }

    func start() async {
        guard updatesTask == nil else { return }

        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                await self?.deliver(result)
            }
        }

        // Includes consumables that could not be delivered before the app closed. Finished
        // consumables disappear from the receipt, so this retry must happen before finish().
        for await result in Transaction.unfinished {
            await deliver(result)
        }
    }

    func productInfo() async -> [ProProduct: ProProductInfo] {
        guard let products = try? await loadProducts() else { return [:] }
        var result: [ProProduct: ProProductInfo] = [:]

        for product in products {
            guard let known = ProProduct(rawValue: product.id) else { continue }
            let eligible: Bool
            if known == .monthly,
               product.subscription?.introductoryOffer != nil,
               let subscription = product.subscription {
                eligible = await subscription.isEligibleForIntroOffer
            } else {
                eligible = false
            }
            result[known] = ProProductInfo(
                product: known,
                displayPrice: product.displayPrice,
                isEligibleForIntroOffer: eligible
            )
        }
        return result
    }

    func purchase(_ product: ProProduct) async -> PurchaseOutcome {
        let accountToken: UUID
        switch await SavedPaletteService.appleAppAccountToken() {
        case .success(let token):
            accountToken = token
        case .failure(let error):
            return .failed(error.purchaseMessage)
        }

        do {
            let products = try await loadProducts()
            guard let storeProduct = products.first(where: { $0.id == product.rawValue }) else {
                return .failed("That purchase is not available in your App Store right now.")
            }
            guard productMatchesConfiguredKind(storeProduct, expected: product.kind) else {
                return .failed("This product is configured incorrectly in the App Store.")
            }

            switch try await storeProduct.purchase(options: [.appAccountToken(accountToken)]) {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    return .failed("The App Store could not verify this purchase.")
                }
                guard transaction.productID == product.rawValue else {
                    return .failed("The App Store returned a different ColorSense product. Try Restore Purchases.")
                }
                guard transaction.appAccountToken == accountToken else {
                    return .failed("This purchase is linked to a different ColorSense account.")
                }
                return await reconcile(verification, transaction: transaction)
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed("The App Store returned an unknown purchase result.")
            }
        } catch {
            return .failed("The purchase could not be completed. Please try again.")
        }
    }

    func restore() async -> PurchaseOutcome {
        guard await hasAuthenticatedSession() else {
            return .failed("Sign in to ColorSense before restoring purchases.")
        }

        // Apple documents that this can show an App Store authentication prompt, so it runs only
        // from the explicit Restore Purchases button. A sync failure must not hide an entitlement
        // the backend already verified and persisted, as can happen after a successful purchase.
        let syncFailed: Bool
        do {
            try await syncAppStore()
            syncFailed = false
        } catch {
            syncFailed = true
        }

        var foundSubscription = false
        for await verification in Transaction.currentEntitlements {
            guard case .verified(let transaction) = verification,
                  let product = ProProduct(rawValue: transaction.productID),
                  product.kind == .autoRenewable else { continue }
            foundSubscription = true
            let outcome = await reconcile(verification, transaction: transaction)
            if case .purchased = outcome { continue }
            return outcome
        }

        if foundSubscription { return .purchased }

        // A finished consumable is intentionally absent from StoreKit's current entitlements.
        // The authenticated backend is also the durable entitlement source after a subscription
        // transaction has already been delivered and finished.
        switch await fetchCurrentPlan() {
        case .success(let plan) where plan == "pro" || plan == "business":
            return .purchased
        case .success where syncFailed:
            return .failed("Purchases could not be restored. Please try again.")
        case .success:
            return .failed("No active ColorSense purchase was found to restore.")
        case .failure(let error):
            return .failed(error.purchaseMessage)
        }
    }

    private func loadProducts() async throws -> [Product] {
        if productsByID.count == ProProduct.allCases.count {
            return Array(productsByID.values)
        }
        let products = try await Product.products(for: ProProduct.allCases.map(\.rawValue))
        productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
        return products
    }

    private func productMatchesConfiguredKind(_ product: Product, expected: ProProduct.Kind) -> Bool {
        switch expected {
        case .autoRenewable: return product.type == .autoRenewable
        case .consumable: return product.type == .consumable
        }
    }

    private func deliver(_ verification: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = verification,
              ProProduct(rawValue: transaction.productID) != nil else { return }
        _ = await reconcile(verification, transaction: transaction)
    }

    private func reconcile(
        _ verification: VerificationResult<Transaction>,
        transaction: Transaction
    ) async -> PurchaseOutcome {
        switch await SavedPaletteService.reconcileAppleTransaction(verification.jwsRepresentation) {
        case .success(let plan) where plan == "pro" || plan == "business":
            // The delivery response acknowledges this transaction. Refresh the shared
            // entitlement separately so a stale or incorrectly combined plan can never cause a
            // StoreKit transaction to be finished before iOS and the website actually have access.
            switch await SavedPaletteService.currentPlan() {
            case .success(let effectivePlan) where effectivePlan == "pro" || effectivePlan == "business":
                await transaction.finish()
                return .purchased
            case .success, .failure:
                return .failed("The purchase was verified, but Pro access is not active yet. Try Restore Purchases shortly.")
            }
        case .success:
            return .failed("The purchase was verified, but Pro access is not active yet. Try Restore Purchases shortly.")
        case .failure(let error):
            return .failed(error.purchaseMessage)
        }
    }
}

enum ProStoreRegistry {
    static let current: any ProStore = AppConfig.storeKitPurchasesEnabled
        ? StoreKitProStore()
        : PlaceholderProStore()
}

enum ProEntitlement {
    static func isPaid() async -> Bool {
        switch await SavedPaletteService.currentPlan() {
        case .success(let plan): return plan == "pro" || plan == "business"
        case .failure: return false
        }
    }
}
