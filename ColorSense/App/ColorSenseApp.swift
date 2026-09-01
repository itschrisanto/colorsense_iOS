import SwiftUI
import ClerkKit

@main
struct ColorSenseApp: App {
    /// One palette for the whole app — every tool reads and writes this. Owned here so it
    /// outlives any individual screen and restores on launch.
    @State private var paletteStore = PaletteStore()

    init() {
        // Clerk.shared traps if configure() was never called, so this always runs even with
        // the placeholder key from AppConfig — sign-in itself just won't work until a real
        // key is set, which AppConfig already warns about.
        // Routed through the web app's Clerk proxy — see AppConfig.clerkProxyURL for why the
        // publishable key's own host can't be used.
        Clerk.configure(
            publishableKey: AppConfig.clerkPublishableKey,
            options: .init(
                proxyUrl: AppConfig.clerkProxyURL,
                // Both of these already default to exactly these values, derived from the bundle
                // identifier. Stated explicitly because they must match three other places —
                // CFBundleURLTypes in project.yml, and the redirect URI allowlisted on the Clerk
                // instance — and a silent bundle-id change would desync all of them.
                redirectConfig: .init(
                    redirectUrl: "online.colorsense.ios://callback",
                    callbackUrlScheme: "online.colorsense.ios"
                )
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(paletteStore)
                .environment(Clerk.shared)
                // OAuth normally completes inside ASWebAuthenticationSession, but a callback can
                // also arrive as a plain deep link — an email magic link, or the browser handing
                // off via the URL scheme. `handle` ignores URLs it doesn't recognise, so this is
                // safe for any other link the app might one day open.
                .onOpenURL { url in
                    Task { try? await Clerk.shared.handle(url) }
                }
        }
    }
}
