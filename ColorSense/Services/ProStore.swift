import Foundation

/// The seam where In-App Purchase will go.
///
/// Nothing here talks to StoreKit yet, and that is the point: every screen that offers Pro already
/// calls through this protocol, so wiring real purchases is writing one conforming type rather than
/// rewriting the onboarding flow. Until then `PlaceholderProStore` answers `.notConfigured` and the
/// callers behave exactly as they did before.
///
/// # What to do when the paid Apple Developer account lands
///
/// 1. In App Store Connect, create the two **auto-renewable subscriptions** in one subscription
///    group, with the identifiers in `ProProduct`. They must be one group, or a reader cannot move
///    between monthly and yearly without double-paying. Create the **Pro Pass separately as a
///    consumable**, outside that group: it is a one-month one-time purchase that can be bought
///    again once it lapses, which is what a consumable is and what a non-consumable is not.
/// 2. Attach the free trial as an **introductory offer** on the monthly product. It is *not* a
///    third product, which is why `ProProduct` has two cases and `Plan` in the onboarding flow has
///    three. Whatever length is configured there has to match the copy on the plan beat, and it
///    has to be added to the vault's pricing table, which still does not mention a trial at all.
/// 3. Write `StoreKitProStore`, conforming to this protocol: `Product.products(for:)` for `load`,
///    `product.purchase()` for `purchase`, and `AppStore.sync()` plus a `Transaction.currentEntitlements`
///    sweep for `restore`. Verify every transaction before granting anything.
/// 4. Point `ProStore.current` at it and set `isLive` to true.
/// 5. **Add a Restore Purchases control to the plan beat.** App Review requires a restore path for
///    auto-renewable subscriptions, and there is deliberately no dead button for it today. The
///    method is already on this protocol so the call site is obvious.
/// 6. **Show `Product.displayPrice`, never the strings below.** The App Store prices in the
///    viewer's own storefront and currency, and Apple's price points do not map one-to-one onto
///    "$5". The prices on `ProProduct` are right for the descriptive list they feed today and are
///    wrong the moment anything can be bought, for anyone outside the US. `SubscriptionView` and
///    the onboarding plan beat both read them, so both change together.
/// 7. Re-check `PrivacyInfo.xcprivacy`: StoreKit does not add a required-reason API, but confirm
///    nothing else moved with the SDK bump.
///
/// # Why the plan beat still shows while this is a placeholder
///
/// Guideline 3.1.1 makes a purchase screen that cannot purchase a rejection risk on its own. It
/// stays visible because it is being demonstrated and filmed, and because hiding it would lose the
/// design. Before any build is submitted, either finish the wiring above or set `isLive` to false
/// **and** stop presenting the beat: `OnboardingFlowView` already routes past it through
/// `advanceFromAccountAsk()`, so that is a one-line change and not a redesign.
protocol ProStore: Sendable {
    /// Whether real purchases can be made. False for the placeholder, and the single switch that
    /// tells every caller whether this screen is a demo or a shop.
    var isLive: Bool { get }

    func purchase(_ product: ProProduct) async -> PurchaseOutcome
    func restore() async -> PurchaseOutcome
}

/// The App Store product identifiers, in one place so they cannot drift from App Store Connect.
///
/// The trial is not here on purpose: it is an introductory offer on `monthly`, not a product.
///
/// **The Pass is not a subscription and must not be created as one.** The vault sells it as a
/// one-month, one-time $9 purchase, which in StoreKit is a *consumable*: it can be bought again
/// when it lapses, which a non-consumable cannot, and it does not belong in the subscription group
/// with the other two. Getting this wrong is not a display bug, it is a wrong product in App Store
/// Connect that has to be replaced rather than edited.
enum ProProduct: String, CaseIterable, Sendable {
    case monthly = "online.colorsense.ios.pro.monthly"
    case annual = "online.colorsense.ios.pro.annual"
    case pass = "online.colorsense.ios.pro.pass"

    /// What kind of App Store product this is, which decides how it is created and how it is
    /// verified after purchase.
    enum Kind { case autoRenewable, consumable }

    var kind: Kind {
        switch self {
        case .monthly, .annual: return .autoRenewable
        case .pass: return .consumable
        }
    }

    /// Prices come from the vault (`Claude Skill.md` section 3) and are the same on every platform.
    /// The Pass is **$9**: the vault calls that out specifically because it has been misquoted as
    /// $3 and $5 before.
    var price: String {
        switch self {
        case .monthly: return "$5"
        case .annual: return "$39"
        case .pass: return "$9"
        }
    }

    var title: String {
        switch self {
        case .monthly: return "Pro Monthly"
        case .annual: return "Pro Annual"
        case .pass: return "Pro Pass"
        }
    }

    var detail: String {
        switch self {
        case .monthly: return "$5 a month, billed monthly. Cancel any time."
        case .annual: return "$39 a year. Two months cheaper than paying monthly."
        case .pass: return "$9 once, for one month. It does not renew."
        }
    }
}

enum PurchaseOutcome: Equatable, Sendable {
    case purchased
    case cancelled
    case pending
    /// No StoreKit yet. Callers treat this as "carry on", which is what the flow did before this
    /// protocol existed.
    case notConfigured
    case failed(String)
}

/// The stand-in until StoreKit is wired. It buys nothing and says so.
struct PlaceholderProStore: ProStore {
    var isLive: Bool { false }
    func purchase(_ product: ProProduct) async -> PurchaseOutcome { .notConfigured }
    func restore() async -> PurchaseOutcome { .notConfigured }
}

enum ProStoreRegistry {
    /// Swap this for `StoreKitProStore()` when the products exist. Nothing else needs to change.
    static let current: any ProStore = PlaceholderProStore()
}

/// Whether the signed-in account is already paying, read from the same `GET /api/me` the web app's
/// `usePlan` uses and `SubscriptionView` already reads.
///
/// This is what stops onboarding pitching a 7-day trial to somebody who is already Pro on
/// colorsense.online. It works today and needs no StoreKit: the account's plan is server side, so a
/// subscriber who signs in on the phone is known to be a subscriber immediately.
enum ProEntitlement {
    /// True only when the server says this account is on a paid plan. A failed request answers
    /// false, so a network problem shows the offer rather than silently hiding it: being pitched
    /// something you already have is a smaller harm than never being able to buy it.
    static func isPaid() async -> Bool {
        switch await SavedPaletteService.currentPlan() {
        case .success(let plan): return plan == "pro" || plan == "business"
        case .failure: return false
        }
    }
}
