import SwiftUI

/// About: who made this, how to reach us, where we are, and what version this is.
///
/// Every value here is a **brand fact the vault owns** (`Claude Skill.md`), not something invented
/// for the app. The contact address is section 12's, the handle is section 13's `@colorsensehq`,
/// and the legal pages are the two routes the web app actually serves.
///
/// Two things in the reference design are still deliberately **not** copied:
///
/// - **No Cookie Policy.** The web app serves `/privacy-policy` and `/terms` and nothing else. A
///   link to a page that does not exist is worse than an absent link.
/// - **No Support link.** The web's `/support` route renders the **Pro pricing page**, and pointing
///   at an external purchase route from inside the app is exactly what guideline 3.1.1 forbids and
///   what got "Pro is available at colorsense.online" removed already. Email reaches a person
///   anyway.
///
/// The third, **"Leave a review", arrived on 2026-09-09** on the condition it was always waiting
/// for: the App Store record now exists, so there is a real App ID to point at. One thing to know
/// about the interim, because it looks like a bug and is not: `?action=write-review` resolves only
/// once the listing is **public**. Until 1.0 is released, a TestFlight tester who taps it reaches a
/// page the App Store cannot show. That resolves itself at release and needs no code change.
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var feedbackIsPresented = false

    /// `@colorsensehq` on every platform, per the vault. The URLs are built from that handle rather
    /// than recorded anywhere, so they are worth checking once against the live accounts.
    /// The asset name is spelled out rather than derived from `name`. A wrong image name does
    /// not crash and does not warn, it renders an empty slot, which is the same silent failure
    /// this repo already records for a misnamed font.
    private static let socials: [(name: String, asset: String, url: String)] = [
        ("Instagram", "SocialInstagram", "https://instagram.com/colorsensehq"),
        ("Threads", "SocialThreads", "https://www.threads.net/@colorsensehq"),
        ("X", "SocialX", "https://x.com/colorsensehq"),
        ("Facebook", "SocialFacebook", "https://facebook.com/colorsensehq"),
        ("Pinterest", "SocialPinterest", "https://pinterest.com/colorsensehq"),
        ("TikTok", "SocialTikTok", "https://tiktok.com/@colorsensehq"),
    ]

    /// The App Store listing, opened straight onto the review sheet.
    ///
    /// `6809134374` is the app's real Apple ID from App Store Connect, where the record is
    /// **ColorSense: Palette Studio**. It is written out here rather than assembled from the bundle
    /// identifier because the two are unrelated: Apple mints this number, and no value in the app
    /// can be used to derive it.
    private static let writeReviewURL =
        "https://apps.apple.com/app/id6809134374?action=write-review"

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

                        // Last of the three on purpose: they run from the most private way to say
                        // something to the most public one. A review is not "reaching us" in the
                        // way the other two are, but it is the same impulse pointed elsewhere, and
                        // a one-row group of its own would weigh more than the row is worth.
                        Divider().padding(.leading, 50)
                        link("Leave a review", "star", Self.writeReviewURL)
                    }

                    group("Social", note: "@colorsensehq") {
                        ForEach(Array(Self.socials.enumerated()), id: \.element.name) { index, social in
                            if index > 0 { Divider().padding(.leading, 50) }
                            link(social.name, asset: social.asset, social.url)
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

    /// A titled card of rows, optionally with a `note` set against the title.
    ///
    /// The note exists for the Social group, where the vault's own framing is "same handle
    /// everywhere". Repeating `@colorsensehq` on all six rows would be six copies of one fact
    /// rather than six facts, so it is stated once beside the heading instead.
    ///
    /// It sits in a `ViewThatFits` for the same reason the plan card's title and badge do: at
    /// accessibility sizes the pair is wider than the screen, and the heading is the half that
    /// must survive. Stacking is the fallback, never truncation.
    private func group<Content: View>(
        _ title: String,
        note: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            heading(title, note: note)
                .padding(.horizontal, 4)
            VStack(spacing: 0) {
                content()
            }
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    @ViewBuilder
    private func heading(_ title: String, note: String?) -> some View {
        let label = Text(title)
            .font(BrandFont.ui(13, weight: .bold))
            .foregroundStyle(.secondary)

        if let note {
            let value = Text(note)
                .font(BrandFont.ui(13))
                .foregroundStyle(.tertiary)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    label
                    Spacer(minLength: 8)
                    value
                }
                VStack(alignment: .leading, spacing: 2) {
                    label
                    value
                }
            }
            // One statement, so VoiceOver should read it as one rather than stopping twice.
            .accessibilityElement(children: .combine)
        } else {
            label
        }
    }

    private func link(_ title: String, _ systemImage: String, _ url: String) -> some View {
        linkRow(title, url) {
            Image(systemName: systemImage)
                .font(.system(size: 15))
                .frame(width: 22)
        }
    }

    /// A row carrying a brand mark instead of an SF Symbol.
    ///
    /// Each asset is a **template** image: colour was thrown away when they were cut, leaving
    /// only the shape as an alpha mask, so the glyph takes the row's own ink and follows light
    /// and dark like every other icon here. That is the whole reason six marks from six sources
    /// read as one set rather than as six pasted logos.
    ///
    /// They are authored at exactly this size, and like the SF Symbols beside them they do not
    /// scale with Dynamic Type. That is the existing behaviour of this list, not a new decision.
    private func link(_ title: String, asset: String, _ url: String) -> some View {
        linkRow(title, url) {
            Image(asset)
                .renderingMode(.template)
                .frame(width: 22, height: 22)
        }
    }

    private func linkRow<Icon: View>(
        _ title: String,
        _ url: String,
        @ViewBuilder icon: () -> Icon
    ) -> some View {
        Button {
            guard let destination = URL(string: url) else { return }
            openURL(destination)
        } label: {
            HStack(spacing: 12) {
                icon()
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
