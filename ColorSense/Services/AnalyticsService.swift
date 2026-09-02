import Foundation
import PostHog

/// Product analytics, deliberately narrow.
///
/// Adding this reversed a decision recorded in CLAUDE.md — that the Extractor and WCAG Checker do
/// no networking at all, matching their "free, unlimited, no signup" positioning. It was reversed
/// on purpose, and the constraints below are what keep the reversal honest rather than open-ended.
///
/// - **Anonymous.** `identify()` is never called, so nothing is ever attached to a real identity.
///   This is not only a privacy choice: PostHog's own privacy manifest declares its collection as
///   *unlinked*, and identifying users would silently make that declaration false. Person profiles
///   are on (`personProfiles = .always`) because retention is counted per person — see `start()`
///   for why that does not introduce an identifier.
/// - **No session replay.** It records the screen. Not enabled, and enabling it would be a
///   materially larger disclosure than anything declared today.
/// - **No autocapture.** `captureElementInteractions` stays off. Every event in `Event` below was
///   chosen; nothing is gathered because it happened to be observable.
/// - **No user content.** Events carry counts and categories — never hex values, palette names,
///   photos, or anything a user typed or made.
/// - **Opt-out, and it is real.** Turning it off calls PostHog's own `optOut()`, which stops
///   capture inside the SDK rather than merely skipping our call sites.
enum AnalyticsService {
    /// Every event the app sends. A closed list on purpose — a new event should be a deliberate
    /// addition here, not an inline string at a call site.
    enum Event: String {
        // Did a palette get made, and how
        case paletteExtracted = "palette_extracted"
        case paletteGenerated = "palette_generated"
        case extractionFailed = "extraction_failed"

        // Did it get kept — the difference between a toy and a tool
        case paletteSaved = "palette_saved"
        case paletteShared = "palette_shared"
        case colorCopied = "color_copied"

        // Was it worked on
        case colorAdded = "color_added"
        case colorRemoved = "color_removed"
        case toolOpened = "tool_opened"
        case contrastChecked = "contrast_checked"

        // Friction, which is the half that explains a funnel rather than just measuring it
        case permissionDenied = "permission_denied"

        // Demand for something that cannot be bought in-app yet. Exposure, not intent: the
        // locked cards are deliberately not tappable, since a tap target there would edge back
        // toward the purchase call-to-action guideline 3.1.1 made us remove.
        case proFormatsSeen = "pro_formats_seen"
    }

    private static let optOutKey = "analytics.optedOut"

    /// Whether the reader has switched analytics off. Defaults to false — on — which is the norm
    /// for anonymous product analytics, and the alternative collects almost nothing and so
    /// answers no question worth asking.
    static var isOptedOut: Bool {
        get { UserDefaults.standard.bool(forKey: optOutKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: optOutKey)
            newValue ? PostHogSDK.shared.optOut() : PostHogSDK.shared.optIn()
        }
    }

    /// Called once at launch. Does nothing at all when no key is configured, so a checkout
    /// without `POSTHOG_API_KEY` in Secrets.xcconfig simply runs without analytics.
    static func start() {
        guard let key = AppConfig.posthogAPIKey else { return }

        let config = PostHogConfig(apiKey: key, host: AppConfig.posthogHost)
        // Screen views would name our SwiftUI views, which is neither meaningful to us nor
        // something we chose to send. The deliberate `toolOpened` event says the same thing.
        config.captureScreenViews = false
        config.captureElementInteractions = false
        config.sessionReplay = false
        config.captureApplicationLifecycleEvents = true
        config.optOut = isOptedOut

        // Retention is counted per *person*, and the default `.identifiedOnly` gives anonymous
        // users no person profile at all. Since identify() is deliberately never called, that
        // default meant every event was person-less and a retention chart would have been empty.
        // `.always` creates a profile per anonymous install instead.
        //
        // This does not weaken the anonymity above: PostHog already assigns a persistent
        // anonymous distinct id regardless of this setting, so no new identifier is introduced —
        // the difference is only whether PostHog keeps a person record to count against. Nothing
        // is ever attached to a real identity, because identify() is still never called.
        config.personProfiles = .always

        PostHogSDK.shared.setup(config)
    }

    static func capture(_ event: Event, _ properties: [String: Any]? = nil) {
        guard AppConfig.posthogAPIKey != nil else { return }
        PostHogSDK.shared.capture(event.rawValue, properties: properties)
    }
}
