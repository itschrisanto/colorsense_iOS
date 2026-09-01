import SwiftUI
import ClerkKit

@main
struct ColorSenseApp: App {
    init() {
        Clerk.configure(publishableKey: AppConfig.clerkPublishableKey)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(Clerk.shared)
        }
    }
}
