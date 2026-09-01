import SwiftUI
import ClerkKit
import ClerkKitUI

/// Sign-in ties into the existing Free/Pro/Pro Annual/Pro Pass plans (vault: Claude Skill.md
/// section 3), even though v1's own tools (Extractor, WCAG Checker) are free-tier and work
/// without an account. Section order mirrors the web app's Account page, minus Telegram.
struct AccountView: View {
    @Environment(Clerk.self) private var clerk
    @Environment(\.dismiss) private var dismiss

    @State private var authIsPresented = false
    @State private var route: Route?

    private enum Route: String, Identifiable {
        case savedPalettes, profile, subscription, affiliate, deleteAccount
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
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

                    // Everything below needs a user: there is nothing to show and no token to
                    // fetch it with while signed out.
                    if clerk.user != nil {
                        section(title: "Library") {
                            row("Saved palettes", "bookmark", .savedPalettes)
                        }
                        section(title: "Account settings") {
                            row("Profile", "person", .profile)
                            row("Subscription", "bolt", .subscription)
                            row("Affiliate", "hands.clap", .affiliate)
                            row("Delete account", "trash", .deleteAccount, isDestructive: true)
                        }
                    }
                }
                .padding(20)
            }
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
            .sheet(item: $route) { destination in
                switch destination {
                case .savedPalettes: SavedPalettesView()
                case .profile: UserProfileView()
                case .subscription: SubscriptionView()
                case .affiliate: AffiliateView()
                case .deleteAccount: DeleteAccountView()
                }
            }
        }
    }

    private func section<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(BrandFont.ui(11, weight: .bold))
                .foregroundStyle(.secondary)
            VStack(spacing: 1) {
                content()
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(
        _ title: String,
        _ systemImage: String,
        _ destination: Route,
        isDestructive: Bool = false
    ) -> some View {
        Button {
            route = destination
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 15))
                    .frame(width: 22)
                Text(title)
                    .font(BrandFont.ui(16))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(isDestructive ? Color.red : Color.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.secondarySystemBackground))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AccountView()
}
