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
                    if let user = clerk.user {
                        profileHeader(user)
                    } else {
                        Button("Sign in") {
                            authIsPresented = true
                        }
                        .font(BrandFont.ui(16, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(BrandColor.coral)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

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

    /// Avatar, name and email. Replaces Clerk's `UserButton`, whose avatar is toolbar-sized —
    /// too small to anchor a screen. Tapping opens the same profile editor `UserButton` would.
    private func profileHeader(_ user: User) -> some View {
        Button {
            route = .profile
        } label: {
            VStack(spacing: 10) {
                avatar(for: user)
                VStack(spacing: 2) {
                    Text(displayName(for: user))
                        .font(BrandFont.ui(20, weight: .bold))
                    if let email = user.primaryEmailAddress?.emailAddress {
                        Text(email)
                            .font(BrandFont.ui(14))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .contentShape(.rect)
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Profile for \(displayName(for: user))")
    }

    @ViewBuilder
    private func avatar(for user: User) -> some View {
        let size: CGFloat = 88
        // `hasImage` is false for accounts with no picture set, where imageUrl still returns a
        // generated placeholder — checking it lets us show our own initials instead.
        if user.hasImage, let url = URL(string: user.imageUrl) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                initialsAvatar(for: user, size: size)
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay { Circle().strokeBorder(.primary.opacity(0.1), lineWidth: 1) }
        } else {
            initialsAvatar(for: user, size: size)
        }
    }

    private func initialsAvatar(for user: User, size: CGFloat) -> some View {
        Circle()
            .fill(BrandColor.coral.opacity(0.18))
            .frame(width: size, height: size)
            .overlay {
                Text(initials(for: user))
                    .font(BrandFont.ui(30, weight: .bold))
                    .foregroundStyle(BrandColor.coral)
            }
    }

    /// Clerk has no `fullName`, so compose it — falling back through username to the email's
    /// local part, since an account created through Google may carry no name at all.
    private func displayName(for user: User) -> String {
        let parts = [user.firstName, user.lastName].compactMap { $0 }.filter { !$0.isEmpty }
        if !parts.isEmpty { return parts.joined(separator: " ") }
        if let username = user.username, !username.isEmpty { return username }
        if let email = user.primaryEmailAddress?.emailAddress {
            return email.split(separator: "@").first.map(String.init) ?? email
        }
        return "Your account"
    }

    private func initials(for user: User) -> String {
        let letters = [user.firstName, user.lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces).first }
        if !letters.isEmpty { return String(letters).uppercased() }
        return String(displayName(for: user).prefix(1)).uppercased()
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
