import Foundation
import PostHog

/// Product analytics, deliberately narrow.
///
/// Adding this reversed a decision recorded in CLAUDE.md — that the Extractor and WCAG Checker do
/// no networking at all, matching their "free, unlimited, no signup" positioning. It was reversed
/// on purpose, and the constraints below are what keep the reversal honest rather than open-ended.
///
/// - **Anonymous.** `identify()` is never called and `personProfiles` stays `.identifiedOnly`, so
///   no event is ever attached to a person. This is not only a privacy choice: PostHog's own
///   privacy manifest declares its collection as *unlinked*, and identifying users would silently
///   make that declaration false.
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
        case paletteExtracted = "palette_extracted"
        case paletteGenerated = "palette_generated"
        case colorAdded = "color_added"
        case colorRemoved = "color_removed"
        case toolOpened = "tool_opened"
        case paletteShared = "palette_shared"
        case paletteSaved = "palette_saved"
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

        PostHogSDK.shared.setup(config)
    }

    static func capture(_ event: Event, _ properties: [String: Any]? = nil) {
        guard AppConfig.posthogAPIKey != nil else { return }
        PostHogSDK.shared.capture(event.rawValue, properties: properties)
    }
}
