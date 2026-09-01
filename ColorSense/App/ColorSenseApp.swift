import SwiftUI
import ClerkKit

@main
struct ColorSenseApp: App {
    init() {
        // Clerk.shared traps if configure() was never called, so this always runs even with
        // the placeholder key from AppConfig — sign-in itself just won't work until a real
        // key is set, which AppConfig already warns about.
        Clerk.configure(publishableKey: AppConfig.clerkPublishableKey)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(Clerk.shared)
        }
    }
}
