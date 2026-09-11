import SwiftUI
import ClerkKit

/// The reader's visual preference for ColorSense. Stored as a raw value so `@AppStorage` can
/// propagate a change from AccountView all the way to the app root without a separate model.
enum AppAppearance: String, CaseIterable, Identifiable {
    static let storageKey = "appearance.preference"

    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: SwiftUI.ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

@main
struct ColorSenseApp: App {
    /// One palette for the whole app — every tool reads and writes this. Owned here so it
    /// outlives any individual screen and restores on launch.
    @State private var paletteStore = PaletteStore()
    @AppStorage(AppAppearance.storageKey) private var appearance = AppAppearance.system.rawValue

    init() {
        AnalyticsService.start()

        // Clerk.shared traps if configure() was never called, so this always runs even with
        // the placeholder key from AppConfig — sign-in itself just won't work until a real
        // key is set, which AppConfig already warns about.
        // Production is routed through the web app's Clerk proxy; development keys use the Clerk
        // host encoded in the key. See AppConfig.clerkProxyURL for why the paths differ.
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
                .preferredColorScheme(AppAppearance(rawValue: appearance)?.colorScheme)
                // OAuth normally completes inside ASWebAuthenticationSession, but a callback can
                // also arrive as a plain deep link — an email magic link, or the browser handing
                // off via the URL scheme. `handle` ignores URLs it doesn't recognise, so this is
                // safe for any other link the app might one day open.
                .onOpenURL { url in
                    Task { try? await Clerk.shared.handle(url) }
                }
                .task { await ProStoreRegistry.current.start() }
        }
    }
}
