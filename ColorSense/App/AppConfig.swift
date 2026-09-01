import Foundation

enum AppConfig {
    /// Read from Info.plist, which sources it from Config/Secrets.xcconfig at build time.
    /// See Config/Secrets.xcconfig.example and CLAUDE.md "Auth setup".
    static var clerkPublishableKey: String {
        guard
            let key = Bundle.main.object(forInfoDictionaryKey: "CLERK_PUBLISHABLE_KEY") as? String,
            !key.isEmpty,
            key != "pk_test_your_key_here"
        else {
            // Not fatal: sign-in just won't work until a real key is set. A hard crash here
            // would take down the whole app (and the test target, which launches it) over a
            // missing dev secret, which is worse than a broken Account tab during setup.
            print(
                "[ColorSense] Missing CLERK_PUBLISHABLE_KEY. Copy Config/Secrets.xcconfig.example " +
                "to Config/Secrets.xcconfig and fill in the real key from the Clerk dashboard. " +
                "Sign-in will not work until then."
            )
            // Clerk.configure() must always be called (Clerk.shared traps otherwise), and it
            // validates the key's format locally before any network call, so a plain
            // placeholder string fails immediately. This decodes to
            // "colorsense-dev-placeholder.clerk.accounts.dev$", matching Clerk's real key
            // shape (pk_test_ + base64 of "<frontend-api-host>$") so configure() succeeds
            // locally; it only fails once something actually tries to reach that fake host.
            return "pk_test_Y29sb3JzZW5zZS1kZXYtcGxhY2Vob2xkZXIuY2xlcmsuYWNjb3VudHMuZGV2JA"
        }
        return key
    }

    /// Base for the ColorSense API, which backs account-saved palettes. Overridable from
    /// Secrets.xcconfig (`API_BASE_URL`) so a local api-server can be pointed at during
    /// development; defaults to production. The web client uses a same-origin relative path,
    /// so this host has no equivalent constant to port — it is the public site.
    static var apiBaseURL: URL {
        if
            let override = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
            !override.isEmpty,
            override != "$(API_BASE_URL)",
            let url = URL(string: override)
        {
            return url
        }
        return URL(string: "https://colorsense.online/api")!
    }
}
