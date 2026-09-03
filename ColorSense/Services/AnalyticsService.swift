import Foundation
import PostHog

/// Product analytics, deliberately narrow.
///
/// Adding this reversed a decision recorded in CLAUDE.md — that the Extractor and WCAG Checker do
/// no networking at all, matching their "free, unlimited, no signup" positioning. It was reversed
/// on purpose, and the constraints below are what keep the reversal honest rather than open-ended.
///
/// - **Pseudonymous.** `identify()` is never called, so nothing is attached to a Clerk account or
///   another real identity. PostHog assigns a random, persistent ID to the app installation so
///   retention can be measured; `personProfiles = .always` keeps a profile for that install ID.
/// - **No session replay.** It records the screen. Not enabled, and enabling it would be a
///   materially larger disclosure than anything declared today.
/// - **Narrow autocapture.** Screen, element, lifecycle, survey and push autocapture stay off.
///   Fatal error capture is on, but breadcrumbs and logs are not. A final `beforeSend` allowlist
///   admits only `Event` and PostHog's `$exception` event.
/// - **No user content.** Events carry counts and categories — never hex values, palette names,
///   photos, or anything a user typed or made. Error reports contain technical crash diagnostics
///   and stack traces, without recorded interaction steps.
/// - **Opt-out, and it is real.** Turning it off calls PostHog's own `optOut()`, which stops
///   capture inside the SDK rather than merely skipping our call sites.
enum AnalyticsService {
    /// Every event the app sends. A closed list on purpose — a new event should be a deliberate
    /// addition here, not an inline string at a call site.
    enum Event: String, CaseIterable {
        // Did a palette get made, and how
        case appOpened = "app_opened"
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
        case colorReordered = "color_reordered"
        case toolOpened = "tool_opened"
        case contrastChecked = "contrast_checked"

        // Friction, which is the half that explains a funnel rather than just measuring it
        case permissionDenied = "permission_denied"

        // The first-launch funnel. `onboardingMood` and `onboardingChoice` carry only closed
        // enum values from `OnboardingMood` and `OnboardingPath` — never free text, a hex, or
        // anything else the reader supplied.
        // Whether anyone actually opens a file once inside SVG Recolor, which `toolOpened` cannot
        // tell us. Carries only a count, never the file, its name or any colour from it.
        case svgFileOpened = "svg_file_opened"

        case onboardingViewed = "onboarding_viewed"
        case onboardingMood = "onboarding_mood"
        case onboardingChoice = "onboarding_choice"

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

        let config = PostHogConfig(projectToken: key, host: AppConfig.posthogHost)

        // Keep every SDK-owned capture path explicit. Several of these defaults are on in the
        // current SDK, so relying on defaults would let a package update silently expand what the
        // app records beyond the closed Event list above.
        config.captureScreenViews = false
        config.captureElementInteractions = false
        config.sessionReplay = false
        config.captureApplicationLifecycleEvents = false
        config.surveys = false
        config.capturePushNotificationSubscriptions = false
        config.capturePushNotificationOpened = false
        config.errorTrackingConfig.autoCapture = true
        config.errorTrackingConfig.exceptionSteps.enabled = false
        config.preloadFeatureFlags = false
        config.sendFeatureFlagEvent = false
        config.enableSwizzling = false
        config.optOut = isOptedOut

        // Defense in depth: only events named by this app and the one SDK-owned crash event can
        // reach PostHog. This blocks lifecycle, survey and every other `$...` event if a future SDK
        // release changes a default or installs a new integration.
        let allowedEvents = Set(Event.allCases.map(\.rawValue) + ["$exception"])
        config.setBeforeSend { event in
            allowedEvents.contains(event.event) ? event : nil
        }

        // Retention is counted per *person*, and the default `.identifiedOnly` gives anonymous
        // users no person profile at all. Since identify() is deliberately never called, that
        // default meant every event was person-less and a retention chart would have been empty.
        // `.always` creates a profile per anonymous install instead.
        //
        // PostHog assigns a persistent random distinct ID regardless of this setting; `.always`
        // means it also retains a person record for that installation. It remains unlinked to the
        // reader's account because identify() is never called.
        config.personProfiles = .always

        PostHogSDK.shared.setup(config)
        capture(.appOpened)
    }

    static func capture(_ event: Event, _ properties: [String: Any]? = nil) {
        guard AppConfig.posthogAPIKey != nil else { return }
        PostHogSDK.shared.capture(event.rawValue, properties: properties)
    }
}
