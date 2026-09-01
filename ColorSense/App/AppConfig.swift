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
            assertionFailure(
                "Missing CLERK_PUBLISHABLE_KEY. Copy Config/Secrets.xcconfig.example to " +
                "Config/Secrets.xcconfig and fill in the real key from the Clerk dashboard."
            )
            return ""
        }
        return key
    }
}
