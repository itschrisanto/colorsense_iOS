import SwiftUI

/// About: who made this, how to reach us, where we are, and what version this is.
///
/// Every value here is a **brand fact the vault owns** (`Claude Skill.md`), not something invented
/// for the app. The contact address is section 12's, the handle is section 13's `@colorsensehq`,
/// and the legal pages are the two routes the web app actually serves.
///
/// Three things in the reference design were deliberately **not** copied:
///
/// - **No Cookie Policy.** The web app serves `/privacy-policy` and `/terms` and nothing else. A
///   link to a page that does not exist is worse than an absent link.
/// - **No Support link.** The web's `/support` route renders the **Pro pricing page**, and pointing
///   at an external purchase route from inside the app is exactly what guideline 3.1.1 forbids and
///   what got "Pro is available at colorsense.online" removed already. Email reaches a person
///   anyway.
/// - **No "Leave a review".** There is no App Store listing yet, so the link would go nowhere. It
///   belongs here the day the App Store record exists, together with the real App ID.
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    /// `@colorsensehq` on every platform, per the vault. The URLs are built from that handle rather
    /// than recorded anywhere, so they are worth checking once against the live accounts.
    private static let socials: [(name: String, url: String)] = [
        ("Instagram", "https://instagram.com/colorsensehq"),
        ("Threads", "https://www.threads.net/@colorsensehq"),
        ("X", "https://x.com/colorsensehq"),
        ("Facebook", "https://facebook.com/colorsensehq"),
        ("Pinterest", "https://pinterest.com/colorsensehq"),
        ("TikTok", "https://tiktok.com/@colorsensehq"),
    ]

    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    hero

                    group("Reach us") {
                        link("Email us", "envelope", "mailto:hello@colorsense.online")
                    }

                    group("Social") {
                        ForEach(Array(Self.socials.enumerated()), id: \.element.name) { index, social in
                            if index > 0 { Divider().padding(.leading, 50) }
                            link(social.name, "at", social.url)
                        }
                    }

                    group("Legal") {
                        link("Privacy Policy", "hand.raised", "https://colorsense.online/privacy-policy")
                        Divider().padding(.leading, 50)
                        link("Terms of Service", "doc.text", "https://colorsense.online/terms")
                    }

                    Text(version)
                        .font(BrandFont.ui(13))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
                .padding(20)
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 10) {
            ColorSenseAuthLogo()
                .padding(.bottom, -14)

            Text("Color tools that stay free.")
                .font(BrandFont.display(30))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            // The vault is explicit that the extractor and the WCAG checker are never paywalled on
            // either platform, so this is a promise the app can actually keep.
            Text("The Extractor and the WCAG checker are free and unlimited, and always will be.")
                .font(BrandFont.ui(14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("Made by Chris Mendez")
                .font(BrandFont.ui(14, weight: .medium))
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .padding(.horizontal, 20)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(BrandFont.ui(13, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            VStack(spacing: 0) {
                content()
            }
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func link(_ title: String, _ systemImage: String, _ url: String) -> some View {
        Button {
            guard let destination = URL(string: url) else { return }
            openURL(destination)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 15))
                    .frame(width: 22)
                Text(title)
                    .font(BrandFont.ui(16))
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(Color.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // Every row here leaves the app, and that should be said rather than discovered.
        .accessibilityHint("Opens outside ColorSense")
    }
}
