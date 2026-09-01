import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            ExtractorView()
                .tabItem { Label("Extractor", systemImage: "eyedropper") }

            WCAGCheckerView()
                .tabItem { Label("WCAG", systemImage: "checkmark.shield") }

            AccountView()
                .tabItem { Label("Account", systemImage: "person.circle") }
        }
        .tint(BrandColor.coral)
    }
}

#Preview {
    RootTabView()
}
