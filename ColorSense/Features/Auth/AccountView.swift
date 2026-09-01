import SwiftUI
import ClerkKit
import ClerkKitUI

/// Sign-in ties into the existing Free/Pro/Pro Annual/Pro Pass plans (vault: Claude Skill.md
/// section 3), even though v1's own tools (Extractor, WCAG Checker) are free-tier and work
/// without an account. This screen is where plan status will surface once Pro features land on iOS.
struct AccountView: View {
    @Environment(Clerk.self) private var clerk
    @State private var authIsPresented = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                UserButton(signedOutContent: {
                    Button("Sign in") {
                        authIsPresented = true
                    }
                    .font(BrandFont.ui(16, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(BrandColor.coral)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                })
                .prefetchClerkImages()
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 40)
            .navigationTitle("Account")
            .sheet(isPresented: $authIsPresented) {
                AuthView()
            }
        }
    }
}

#Preview {
    AccountView()
}
