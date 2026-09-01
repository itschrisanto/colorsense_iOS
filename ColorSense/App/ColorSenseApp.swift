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
            options: .init(proxyUrl: AppConfig.clerkProxyURL)
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(paletteStore)
                .environment(Clerk.shared)
        }
    }
}
