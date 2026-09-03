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

    @State private var feedbackIsPresented = false

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
                        // Feedback first: it is the one that stays inside the app and reaches a
                        // person without the reader having to compose anything themselves.
                        Button {
                            feedbackIsPresented = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "text.bubble")
                                    .font(.system(size: 15))
                                    .frame(width: 22)
                                Text("Send feedback")
                                    .font(BrandFont.ui(16))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .foregroundStyle(Color.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)

                        Divider().padding(.leading, 50)
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
            .sheet(isPresented: $feedbackIsPresented) { FeedbackView() }
        }
    }

    private var hero: some View {
        VStack(spacing: 10) {
            ColorSenseAuthLogo()
                .padding(.bottom, -14)

            Text("ColorSense")
                .font(BrandFont.display(34))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            // The vault is explicit that the extractor and the WCAG checker are never paywalled on
            // either platform, so this is a promise the app can actually keep.
            Text("The Extractor and the WCAG checker are free and unlimited, and always will be.")
                .font(BrandFont.ui(14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            author
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .padding(.horizontal, 20)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    /// Who built it, with a portrait when one is in the catalog.
    ///
    /// The image is looked up rather than assumed: `UIImage(named:)` returns nil when the asset is
    /// absent, and a missing photo falls back to initials instead of leaving a blank circle or
    /// crashing a preview. That matters because the portrait arrived after the layout did.
    private var author: some View {
        HStack(spacing: 10) {
            Group {
                if UIImage(named: Self.portraitAsset) != nil {
                    Image(Self.portraitAsset)
                        .resizable()
                        .scaledToFill()
                } else {
                    Text("CM")
                        .font(BrandFont.ui(24, weight: .bold))
                        .foregroundStyle(PaletteColor(color: BrandColor.teal).legibleForeground)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(BrandColor.teal)
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(Circle())
            .overlay { Circle().stroke(Color.primary.opacity(0.12), lineWidth: 1) }

            VStack(alignment: .leading, spacing: 2) {
                Text("Developed by")
                    .font(BrandFont.ui(13))
                    .foregroundStyle(.secondary)
                Text("Chrisanto Mendez")
                    .font(BrandFont.ui(17, weight: .bold))
            }
        }
        .padding(.top, 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Developed by Chrisanto Mendez")
    }

    private static let portraitAsset = "AuthorPortrait"

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
