import SwiftUI
import ClerkKit
import ClerkKitUI

/// Sign-in ties into the existing Free/Pro/Pro Annual/Pro Pass plans (vault: Claude Skill.md
/// section 3), even though v1's own tools (Extractor, WCAG Checker) are free-tier and work
/// without an account. This screen is where plan status will surface once Pro features land on iOS.
struct AccountView: View {
    @Environment(Clerk.self) private var clerk
    @Environment(\.dismiss) private var dismiss
    @State private var authIsPresented = false
    @State private var savedPalettesArePresented = false

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

                // Saved palettes live behind the account because that is what they belong to,
                // and it mirrors where the web app puts its Library. Hidden when signed out —
                // there is nothing to show and no token to fetch it with.
                if clerk.user != nil {
                    Button {
                        savedPalettesArePresented = true
                    } label: {
                        HStack {
                            Label("Saved palettes", systemImage: "bookmark")
                                .font(BrandFont.ui(16))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.top, 40)
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $authIsPresented) {
                AuthView()
            }
            .sheet(isPresented: $savedPalettesArePresented) {
                SavedPalettesView()
            }
        }
    }
}

#Preview {
    AccountView()
}
