import SwiftUI
import ClerkKit
import ClerkKitUI

/// How the reader left onboarding. A closed set, and the only thing the analytics event carries.
enum OnboardingExit: String, CaseIterable, Identifiable, Equatable {
    case signUp = "sign_up"
    case signIn = "sign_in"
    case later

    var id: String { rawValue }
}

/// The first run, built out of the app's own palette bands.
///
/// The earlier version put rounded cards and a gradient scrim over the palette, which is the house
/// style of every SaaS onboarding and hid the one thing that makes ColorSense look like itself.
/// This has no cards, no scrim and no gradient. The screen *is* bands: a tall hero band carrying
/// the type, thin colour strips under it, and an action band at the bottom, all full bleed with
/// hard edges, exactly like the home screen. Text takes its colour from the band it sits on via
/// `legibleForeground`, which is the same `ContrastCalculator` route every swatch label uses.
///
/// Three beats:
///
/// 1. `hello` all five bands are CORAL, so the screen reads as one solid field. It labels itself
///    the way the app labels a swatch, with the real Name That Color match for #FF6B6B.
/// 2. `mood` the bands **split**: the five slots animate from coral to a real palette. Picking a
///    mood recolours them live underneath. The split is the product demo, and nothing explains it.
/// 3. `keep` the palette is theirs, and the account ask lands here, after they have made something
///    rather than before.
///
/// The account ask is a **soft gate**: create an account, sign in, or carry on without one. That is
/// deliberate. App Review guideline 5.1.1(v) does not allow requiring registration for features
/// that do not need an account, and the Extractor and WCAG checker both run entirely on device.
struct OnboardingFlowView: View {
    let onComplete: () -> Void

    private enum Beat: Equatable {
        /// Holds the launch screen's own composition for a beat after the app takes over.
        ///
        /// The system launch screen is real but nobody sees it: iOS caches the launch snapshot per
        /// install, so an upgrade keeps showing the previous one until the app is deleted, and on
        /// a fast device it is gone in a frame or two regardless. This continues the same image in
        /// the same place so the brand moment actually lands, then advances itself. No tap.
        case splash
        /// She says who she is. The splash has already shown her on coral, so this is the same
        /// character arriving with words rather than a second, unexplained brand slide.
        case hello
        case naming
        case mood
        case keep
        /// Design only. Nothing here is wired to StoreKit, and it must be before this ships.
        case plan
    }

    private enum Plan: String, CaseIterable, Identifiable {
        case trial
        case monthly
        case annual

        var id: String { rawValue }

        var title: String {
            switch self {
            case .trial: return "7 days free"
            case .monthly: return "Monthly"
            case .annual: return "Yearly"
            }
        }

        /// $5 a month and $39 a year are the vault's Pro Monthly and Pro Annual prices
        /// (Claude Skill.md section 3). The trial is **not** in the vault: it is a StoreKit
        /// introductory offer and, if it stays, a pricing decision that belongs there.
        var detail: String {
            switch self {
            case .trial: return "Then $5 a month. Cancel any time before it ends."
            case .monthly: return "Billed every month."
            case .annual: return "Billed once a year."
            }
        }

        /// Blank for the trial, because its whole point is that nothing is charged yet and a
        /// price in that slot would contradict the line beside it.
        var price: String {
            switch self {
            case .trial: return ""
            case .monthly: return "$5"
            case .annual: return "$39"
            }
        }

        /// A colour per plan, so three choices read as three things rather than three identical
        /// boxes. Taken from the brand kit rather than invented, same as everywhere else.
        var accent: Color {
            switch self {
            case .trial: return BrandColor.yellow
            case .monthly: return BrandColor.teal
            case .annual: return BrandColor.coral
            }
        }

        /// "SAVE 35%" is arithmetic, not a claim: $5 a month is $60 a year against the vault's $39.
        /// If either price moves in the vault, this number moves with it.
        var badge: String? {
            switch self {
            case .trial: return "START HERE"
            case .monthly: return nil
            case .annual: return "SAVE 35%"
            }
        }

        var action: String {
            switch self {
            case .trial: return "Start my free trial"
            case .monthly: return "Subscribe monthly"
            case .annual: return "Subscribe yearly"
            }
        }
    }

    private struct AuthRoute: Identifiable {
        let mode: AuthView.Mode
        var id: String { mode.rawValue }
    }

    @Environment(PaletteStore.self) private var store
    @Environment(Clerk.self) private var clerk
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var beat: Beat = .splash
    @State private var chosenMood: OnboardingMood?
    @State private var restorePalette: ExtractedPalette?
    @State private var authRoute: AuthRoute?
    @State private var chosenPlan: Plan = .trial
    /// Recorded when the account beat is answered, sent when the flow actually ends.
    @State private var exit: OnboardingExit = .later
    @State private var recordedView = false

    /// Definite control heights, scaled by Dynamic Type.
    ///
    /// These are `@ScaledMetric` rather than `.frame(minHeight:)` for a reason that cost real time.
    /// A minimum height is a *flexible* frame: offered more, it grows. These controls sit in a band
    /// beside a hero that is `maxHeight: .infinity`, and on a screen with surplus height they took
    /// a share of it, painting their fill down over the band's own bottom padding while the label
    /// stayed at the top. With three controls the surplus split three ways and only looked loose;
    /// on the signed-in `keep` beat, where there is a single Continue, one control stretched from
    /// 52pt to 88pt and ran off the bottom of the screen.
    ///
    /// Neither `.fixedSize(vertical:)` on the control nor on the band stopped it. A definite height
    /// does, and `@ScaledMetric` keeps it honest at larger text sizes.
    @ScaledMetric(relativeTo: .body) private var primaryHeight: CGFloat = 54
    @ScaledMetric(relativeTo: .body) private var secondaryHeight: CGFloat = 52
    @ScaledMetric(relativeTo: .body) private var quietHeight: CGFloat = 44
    /// Whether the signed-in account already pays, fetched ahead of the decision rather than at it.
    /// Nil means not known yet, which is treated as "not paying", so the offer shows.
    @State private var isPaidAccount: Bool?

    private var isAccessibilitySize: Bool { dynamicTypeSize.isAccessibilitySize }

    /// The five band colours. In `hello` every slot is coral, so the screen looks like a single
    /// coral field. Moving to `mood` animates those same five slots to the real palette, which is
    /// what makes the field appear to split rather than cut.
    private var bandColors: [Color] {
        // Three flat fields before the split: CORAL to arrive on, TEAL to meet her, CORAL again
        // to meet the idea.
        if beat == .splash { return Array(repeating: BrandColor.coral, count: 5) }
        if beat == .hello { return Array(repeating: BrandColor.teal, count: 5) }
        if beat == .naming { return Array(repeating: BrandColor.coral, count: 5) }
        if beat == .plan { return Array(repeating: BrandColor.purple, count: 5) }
        let colors = store.palette.colors.map(\.color)
        guard colors.count >= 5 else {
            return colors + Array(repeating: colors.last ?? BrandColor.coral, count: 5 - colors.count)
        }
        return Array(colors.prefix(5))
    }

    /// Label colour for a band, measured against the band it actually sits on rather than assumed.
    private func foreground(onBandAt index: Int) -> Color {
        if beat == .hello {
            return PaletteColor(color: BrandColor.teal).legibleForeground
        }
        if beat == .splash {
            return PaletteColor(hex: 0xFF6B6B, dominance: 0).legibleForeground
        }
        if beat == .naming {
            return PaletteColor(hex: 0xFF6B6B, dominance: 0).legibleForeground
        }
        if beat == .plan {
            return PaletteColor(color: BrandColor.purple).legibleForeground
        }
        let colors = store.palette.colors
        guard index < colors.count else { return colors.last?.legibleForeground ?? .white }
        return colors[index].legibleForeground
    }

    /// The strips collapse on `hello`. They are the same TEAL as the hero there so they show
    /// nothing, but they still take 252pt out of the band, which pushed Lauma a full 126pt above
    /// the centre of the screen she is supposed to be standing in the middle of.
    private var stripHeight: CGFloat {
        if beat == .splash || beat == .hello || beat == .naming || beat == .plan { return 0 }
        return isAccessibilitySize ? 34 : 84
    }

    /// The primary button inverts the band it sits on: the fill is the band's own measured ink,
    /// and the label is the band's colour.
    ///
    /// Three treatments were tried before this one. Plain `actionForeground` buttons made the flow
    /// read as black bars on flat colour. Filling with a second brand colour instead (CORAL on
    /// TEAL, TEAL on CORAL, YELLOW on BLURPLE) fixed that, but made the button an unrelated third
    /// colour whose label still measured black, so the button and the type on the screen shared
    /// nothing. Inverting ties them together: the pill is the same ink the headline is set in, and
    /// the word inside it is the screen's own colour.
    ///
    /// It also cannot fail a contrast check. `legibleForeground` already chose the ink that
    /// contrasts most with this band, so swapping the two keeps exactly that ratio, on a flat
    /// brand field and on whichever palette the reader's mood turns out to be.
    ///
    /// Only the primary inverts. The secondary and quiet controls stay in the band's ink, because
    /// a filled second button would compete with the one the reader is meant to press.
    private var primaryFill: Color { actionForeground }

    /// The band's own colour, read back out for the button's label.
    private var primaryLabel: Color { bandColors[4] }

    private var heroForeground: Color { foreground(onBandAt: 0) }
    private var actionForeground: Color { foreground(onBandAt: 4) }

    var body: some View {
        VStack(spacing: 0) {
            hero
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                // `.id(beat)` is what makes the swap an insertion and a removal rather than a
                // silent subtree replacement, which is the only way a transition can run at all.
                // It sits inside the background so the band colour is untouched by it and keeps
                // morphing straight through the change.
                .id(beat)
                .transition(OnboardingMotion.beatContent(reduceMotion: reduceMotion))
                // Deliberately NOT clipped. A `.clipped()` was added here with the slide, reasoning
                // that the outgoing page would be seen travelling across the strips. It cannot: the
                // slide is horizontal, so a leaving page exits past the side of the screen and
                // never crosses the bands below. What clipping did instead was cut Lauma off at the
                // hero's bottom edge on `hello` and `keep`, where she is a bottomTrailing overlay
                // offset two points *past* it so she stands on the seam. Her hooves were sliced.
                .background(bandColors[0])

            // Thin colour strips. They carry no content, which is the point: they are the palette
            // sitting underneath the words, visible the whole time.
            ForEach(1..<4, id: \.self) { index in
                bandColors[index]
                    .frame(height: stripHeight)
            }

            actionBand
                .id(beat)
                .transition(OnboardingMotion.beatContent(reduceMotion: reduceMotion))
                .background(bandColors[4])
        }
        .ignoresSafeArea()
        .animation(PaletteMotion.replace(reduceMotion: reduceMotion), value: store.palette.colors)
        .sensoryFeedback(.selection, trigger: chosenMood)
        .onAppear {
            restorePalette = store.palette
            guard !recordedView else { return }
            recordedView = true
            AnalyticsService.capture(.onboardingViewed)
        }
        .sheet(item: $authRoute) { route in
            AuthView(mode: route.mode)
                // Clerk's own dashboard logo is a light-only bitmap on an opaque white canvas,
                // which looks wrong in dark mode. Same local mark the rest of the app uses.
                .clerkAppIconView { ColorSenseAuthLogo() }
        }
        // Signing in dismisses the auth sheet but not this, so finish once Clerk actually has a
        // user. That way the reader is never returned to an ask they have already answered.
        .onChange(of: clerk.user?.id) { _, id in
            guard id != nil, beat == .keep else { return }
            record(authRoute?.mode == .signUp ? .signUp : .signIn)
            advanceFromAccountAsk()
        }
        .accessibilityAddTraits(.isModal)
        // The splash timer lives here, on the root, and not on the splash subview.
        //
        // It was on the subview, and it silently skipped the whole screen on device while working
        // in the simulator. `try? await Task.sleep` swallows the `CancellationError` a cancelled
        // task throws, so execution fell straight through to `advance` the instant anything tore
        // the subview down and rebuilt it. On a phone the app initialises fast enough that an
        // early re-render did exactly that; the simulator is slow and idle in that window, so it
        // never reproduced there.
        //
        // Two things fix it: the root view keeps its identity for the whole flow so the task is
        // not cancelled by ordinary re-renders, and the cancellation guard means a cancelled sleep
        // can never be mistaken for an elapsed one.
        // Ahead of the decision, not at it. By the time anyone reaches the account ask this has
        // long since settled, and if it has not, the offer shows rather than the flow stalling.
        .task(id: clerk.user?.id) {
            guard clerk.user != nil else {
                isPaidAccount = nil
                return
            }
            isPaidAccount = await ProEntitlement.isPaid()
        }
        .task(id: beat) {
            guard beat == .splash else { return }
            // Five seconds, asked for directly on 2026-09-03: at 1.5s the blink was over before
            // the reader had focused on her face, and on device it was missed entirely. This is a
            // long hold for a screen with no controls, so if it ever starts to feel like a wait,
            // shorten it rather than adding a skip control that invites a tap past the one moment
            // the screen exists to show.
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled, beat == .splash else { return }
            advance(to: .hello)
        }
    }

    // MARK: - Hero band

    /// The hero scrolls at accessibility sizes, on every beat.
    ///
    /// The band layout gives the hero the space the action band does not need, and at large text
    /// sizes several beats want more than that. An overflowing hero does not compress, it pushes
    /// the action band off the bottom of the screen, which takes the only way forward with it: on
    /// `keep` that meant "Maybe later" hanging off the edge, and on `plan` it swallowed both
    /// buttons. This was first fixed for `plan` alone, which was treating the symptom, since
    /// nothing about the cause was specific to that beat.
    ///
    /// The controls survive because they live in their own band, outside this scroll.
    @ViewBuilder
    private var hero: some View {
        // The splash is exempt. Every other beat scrolls at accessibility sizes because its copy
        // grows past the band, but nothing on the splash scales: the mascot is a fixed height and
        // the wordmark is deliberately `uiFixed`. Inside a `ScrollView` its centring spacers have
        // no height to distribute, so it packed against the top of the screen with her ears cut
        // off by the status bar and two thirds of the display empty underneath.
        if isAccessibilitySize && beat != .splash {
            ScrollView {
                heroContent
            }
            .scrollIndicators(.hidden)
        } else {
            heroContent
        }
    }

    @ViewBuilder
    private var heroContent: some View {
        switch beat {
        case .splash: splash
        case .hello: introduction
        case .mood: moodHero
        case .naming: namingHero
        case .keep: proseHero
        case .plan: planHero
        }
    }

    /// Lauma on top, the words underneath. Same vertical order as the introduction before it, so
    /// the two screens read as one sequence rather than two unrelated layouts, and she stops
    /// competing with the headline for the same corner.
    /// The Pro offer. **Design only: nothing here talks to StoreKit.**
    ///
    /// Two things have to happen before this can ship. App Review guideline 3.1.1 requires digital
    /// goods to go through In-App Purchase, so these buttons must be wired to real products, and a
    /// purchase screen that does nothing is itself a rejection. The 7-day trial is a StoreKit
    /// introductory offer configured in App Store Connect, and it is not in the vault's pricing
    /// table yet. Until both are done, keep this behind the same skip the rest of the flow has.
    /// Scrolling at accessibility sizes is handled by `hero` for every beat, so this is just the
    /// content.
    private var planHero: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            // Smaller than the other beats: three plan cards need the room, and she is a
            // reaction here rather than the subject. `height` is the whole frame, not Lauma.
            LaumaClip(clip: .cheer, height: isAccessibilitySize ? 104 : 162)

            VStack(spacing: 6) {
                Text("Try Pro free\nfor 7 days.")
                    .font(BrandFont.display(isAccessibilitySize ? 30 : 42))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Brand kits, AI harmonies and logo-free exports. Everything you have used so far stays free.")
                    .font(BrandFont.ui(15))
                    .opacity(0.82)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 300)
                    .padding(.top, 10)
            }
            .padding(.top, 16)

            VStack(spacing: 10) {
                ForEach(Plan.allCases) { plan in
                    planCard(plan)
                }
            }
            .padding(.top, 20)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .foregroundStyle(heroForeground)
        .padding(.horizontal, 22)
        .padding(.top, 68)
        .padding(.bottom, 8)
    }

    /// One plan, as a card that wears its own colour.
    ///
    /// The chosen card is **filled** with that colour and the others are outlined with a stripe of
    /// theirs, which is what separates the three at a glance on a flat BLURPLE field. Three
    /// identical outlined boxes made the reader compare prose to tell them apart.
    ///
    /// Every label colour on a filled card is measured against the fill through
    /// `legibleForeground`, never assumed: YELLOW and TEAL take black type and this app exists to
    /// catch the pairing that does not.
    private func planCard(_ plan: Plan) -> some View {
        let isChosen = chosenPlan == plan
        let onFill = PaletteColor(color: plan.accent).legibleForeground
        let label = isChosen ? onFill : heroForeground
        return Button { chosenPlan = plan } label: {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    let title = Text(plan.title).font(BrandFont.ui(16, weight: .bold))
                    let badge = plan.badge.map { text in
                        Text(text)
                            .font(BrandFont.ui(10, weight: .bold))
                            .kerning(0.5)
                            .foregroundStyle(isChosen ? onFill : PaletteColor(color: plan.accent).legibleForeground)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            // On a filled card the badge cannot use the fill colour it would
                            // normally take, so it inverts instead and stays readable.
                            .background(isChosen ? onFill.opacity(0.16) : plan.accent)
                    }

                    // Side by side while both fit, stacked once they do not. At accessibility
                    // sizes the row was too wide and the title truncated to "7 days f...", which
                    // is the one string on this card that has to survive.
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) {
                            title
                            badge
                        }
                        VStack(alignment: .leading, spacing: 5) {
                            title
                            badge
                        }
                    }

                    Text(plan.detail)
                        .font(BrandFont.ui(13))
                        .opacity(0.8)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)

                Text(plan.price)
                    .font(BrandFont.ui(18, weight: .bold))
            }
            .padding(.vertical, 12)
            .padding(.leading, 18)
            .padding(.trailing, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(label)
            .background(isChosen ? plan.accent : .clear)
            // The stripe is an overlay rather than a row in the HStack. As a child it was a bare
            // `Color`, which is greedy for height, so it stretched the two unchosen cards about
            // 60% taller than the chosen one and the three stopped reading as a set.
            .overlay(alignment: .leading) {
                if !isChosen {
                    plan.accent.frame(width: 6)
                }
            }
            .overlay {
                Rectangle().stroke(
                    heroForeground.opacity(isChosen ? 0 : 0.3),
                    lineWidth: 1
                )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            [plan.title, plan.price, plan.detail, plan.badge]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: ". ")
        )
        .accessibilityAddTraits(isChosen ? [.isSelected] : [])
    }

    private var namingHero: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            // `height` is the whole frame, not Lauma, so this sits a little above the still it
            // replaced.
            LaumaClip(clip: .naming, height: isAccessibilitySize ? 158 : 236)

            VStack(spacing: 6) {
                Text("Every color has a name.")
                    .font(BrandFont.display(isAccessibilitySize ? 30 : 42))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                // The proof, in the app's own swatch type, directly under the claim.
                Text("Bittersweet")
                    .font(BrandFont.ui(20, weight: .bold))
                    .padding(.top, 10)
                Text("#FF6B6B")
                    .brandMono(13, weight: .medium)
                    .opacity(0.75)

                Text("This whole screen is CORAL. Tap any color in the app and it tells you the name.")
                    .font(BrandFont.ui(15))
                    .opacity(0.82)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    // A centred paragraph set to the full band width breaks into long ragged
                    // lines. Capping the measure is what makes it read as a caption under the
                    // headline rather than a loose block of text.
                    .frame(maxWidth: 300)
                    .padding(.top, 14)
            }
            .padding(.top, 18)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .foregroundStyle(heroForeground)
        .padding(.horizontal, 22)
        .padding(.top, 68)
        .padding(.bottom, 8)
    }

    /// The launch screen, continued. Same pose, same coral, no words and no controls, so the
    /// handover from the system launch image is invisible.
    private var splash: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            // The launch screen's colour, her head at the launch screen's size, and one blink.
            // The blink frames are the only place a real closed-eye drawing exists.
            // A much tighter gap than the default: three or four blinks land inside the
            // five-second hold, so the animation cannot be missed the way one blink in 1.5s was.
            LaumaBlink(height: 190, gap: 0.5...1.1)
            Spacer(minLength: 0)
            // She keeps the middle of the space *above* the wordmark rather than the middle of the
            // screen, which is the same centring problem the `hello` beat solved by collapsing its
            // strips: anything added below her pushes her off centre unless it is given its own room.
            SplashWordmark(ink: foreground(onBandAt: 0))
                .padding(.bottom, 36)
        }
        .frame(maxWidth: .infinity)
    }

    /// Her introduction, and nothing else on the screen. No wordmark, no headline, no supporting
    /// paragraph: she is centred on a flat TEAL field with one speech bubble. The launch screen
    /// already showed her face and the next beat carries the product idea, so this beat only has
    /// to do the one thing its copy says.
    private var introduction: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            // DM Sans, not the Bebas display face. Bebas Neue is caps-only, so it would render
            // "I'm Lauma" as "I'M LAUMA" and lose the casing this line is written in.
            Text("HI! I'm Lauma.")
                .font(BrandFont.ui(isAccessibilitySize ? 22 : 28, weight: .bold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 22)
                .padding(.vertical, 16)
                // Glass rather than a solid fill, so the bubble picks up the system appearance
                // instead of being one fixed colour. `.primary` inside it flips with the same
                // setting, which is what keeps the line readable in both.
                .background(.ultraThinMaterial, in: SpeechBubble())
                .padding(.bottom, 4)

            // The animated wave, not the still WELCOME pose. `height` here is the whole frame
            // rather than Lauma herself, and she fills about 93% of it at her largest, so this is
            // a little taller than the still she replaced.
            LaumaClip(clip: .wave, height: isAccessibilitySize ? 205 : 320)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
        .padding(.top, 68)
        .padding(.bottom, 8)
    }

    private var moodHero: some View {
        heroStack {
            // She sits *in* the composition on this beat, beside the question she is asking,
            // rather than being pinned to a corner of the band. Cornered, she floated in the
            // empty top of the hero with nothing tying her to the words.
            HStack(alignment: .bottom, spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    headlineText
                    subheadText
                }
                Spacer(minLength: 0)
                // Flipped so the GUIDE pose's arm points back at the choices. Unflipped she
                // stands on the right pointing off the edge of the screen.
                LaumaStage(
                    pose: chosenMood?.pose ?? .guiding,
                    height: laumaHeight,
                    // Only the GUIDE pose is pointing at anything, so only that one is mirrored.
                    flipped: chosenMood == nil
                )
            }

            moodPicker
                .padding(.top, 18)
        }
    }

    private var proseHero: some View {
        heroStack {
            headlineText

            // The app's own swatch label, in the app's own type, sitting directly under the
            // claim it is evidence for. Orphaned at the top of the band it read as decoration.
            if beat == .naming {
                Text("Bittersweet")
                    .font(BrandFont.ui(26, weight: .bold))
                    .padding(.top, 14)
                Text("#FF6B6B")
                    .brandMono(15, weight: .medium)
                    .opacity(0.75)
            }

            subheadText
                .padding(.top, 10)

            // `naming` has no picker under it, so a second spacer centres the block in the band
            // instead of leaving it stranded at the bottom of a tall empty field.
            if beat == .naming {
                Spacer(minLength: 12)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            // She stands on the seam between the hero band and the strips below it.
            LaumaStage(pose: pose, height: laumaHeight)
                .padding(.trailing, 10)
                .offset(y: 2)
        }
    }

    private func heroStack<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 12)
            content()
        }
        .foregroundStyle(heroForeground)
        .padding(.horizontal, 22)
        .padding(.top, 68)
        .padding(.bottom, 8)
    }

    private var headlineText: some View {
        Text(headline)
            .font(BrandFont.display(isAccessibilitySize ? 34 : 52))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var subheadText: some View {
        Text(subhead)
            .font(BrandFont.ui(15))
            .opacity(0.8)
            .fixedSize(horizontal: false, vertical: true)
            // Keep the sentence clear of Lauma where she is an overlay pinned bottom-trailing.
            // On `mood` she is a sibling in an HStack, so the layout already reserves her width.
            .padding(.trailing, beat == .mood ? 0 : proseInsetForLauma)
    }

    private var headline: String {
        switch beat {
        case .naming: return "Every color\nhas a name."
        case .mood: return "Where do\nyou start?"
        case .keep: return "This one\nis yours."
        // The other beats compose their own views and never read this.
        case .splash, .hello, .plan: return ""
        }
    }

    private var subhead: String {
        switch beat {
        case .mood:
            return chosenMood?.reaction ?? "The palette changes under you as you pick."
        case .keep:
            // The controls below change when there is already a user, so the copy has to as well,
            // or the screen asks for an account in prose while offering a Continue button.
            return clerk.user == nil
                ? "Create a free account to keep it. Your palettes sync with colorsense.online, so they are on your laptop too."
                : "It is saved to your account, so it is on your laptop too."
        case .splash, .hello, .naming, .plan: return ""
        }
    }

    /// Only the beats that place her through the shared overlay read this. `splash`, `hello` and
    /// `naming` name their own pose inline.
    private var pose: LaumaPose {
        switch beat {
        case .mood: return chosenMood?.pose ?? .guiding
        case .keep: return .celebrating
        case .splash, .hello, .naming, .plan: return .welcome
        }
    }

    private var laumaHeight: CGFloat {
        if isAccessibilitySize { return 86 }
        switch beat {
        case .mood: return chosenMood == nil ? 150 : 158
        case .keep: return 176
        case .splash, .hello, .naming, .plan: return 200
        }
    }

    /// Roughly how wide Lauma is at the current pose height. The sprites are trimmed to their
    /// alpha box and all sit near a 0.62 width-to-height ratio, so one factor covers every pose
    /// without measuring each one.
    private var proseInsetForLauma: CGFloat {
        laumaHeight * 0.62 + 16
    }

    // MARK: - Mood picker

    /// Four palettes shown as palettes. Each tile is a miniature of the home screen, a stack of the
    /// five real colours, rather than an icon and a subtitle in a rounded row.
    private var moodPicker: some View {
        // Top-aligned: at accessibility sizes a name that wraps to two lines otherwise pushes its
        // own swatch strip up and breaks the row.
        HStack(alignment: .top, spacing: 8) {
            ForEach(OnboardingMood.allCases) { mood in
                let isChosen = chosenMood == mood
                Button { choose(mood) } label: {
                    VStack(spacing: 0) {
                        VStack(spacing: 0) {
                            ForEach(mood.colors) { swatch in
                                swatch.color.frame(maxWidth: .infinity)
                            }
                        }
                        .frame(height: isAccessibilitySize ? 44 : 78)
                        .overlay {
                            Rectangle()
                                .stroke(BrandColor.coral, lineWidth: isChosen ? 4 : 0)
                        }

                        Text(mood.title)
                            .font(BrandFont.ui(12, weight: .bold))
                            .foregroundStyle(heroForeground)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.top, 6)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(mood.title). \(mood.summary)")
                .accessibilityAddTraits(isChosen ? [.isSelected] : [])
            }
        }
    }

    // MARK: - Action band

    private var actionBand: some View {
        VStack(spacing: 10) {
            switch beat {
            case .splash:
                // No controls: it advances itself, and a button here would invite a tap on a
                // screen that has nothing to say yet.
                Color.clear.frame(height: 1)

            case .hello:
                primary("Nice to meet you") { advance(to: .naming) }
                quiet("Skip for now") { skip() }

            case .naming:
                primary("Show me") { advance(to: .mood) }
                quiet("Skip for now") { skip() }

            case .mood:
                // Outlined until there is something to keep. A dimmed fill just looked like a
                // muddy grey slab sitting on the band.
                if chosenMood == nil {
                    secondary("Pick one first") {}
                        .disabled(true)
                        .opacity(0.55)
                } else {
                    primary("Keep this one") { advance(to: .keep) }
                }
                quiet("Skip for now") { skip() }

            case .keep:
                // Somebody already signed in has nothing to answer here. `onChange(of:)` only
                // fires when the id *changes*, so a session restored at launch used to leave this
                // beat asking an authenticated reader to create an account, and both buttons
                // opened `AuthView` for a user who was already in it.
                if clerk.user != nil {
                    primary("Continue") { advanceFromAccountAsk() }
                } else {
                    primary("Create a free account") { authRoute = AuthRoute(mode: .signUp) }
                    secondary("I already have one") { authRoute = AuthRoute(mode: .signIn) }
                    quiet("Maybe later") { record(.later); advanceFromAccountAsk() }
                }

            case .plan:
                primary(chosenPlan.action) { buy() }
                quiet("Not now") { onComplete() }
            }
        }
        .foregroundStyle(actionForeground)
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 34)
    }

    /// The buttons take their height from padding, and pad their label before expanding.
    ///
    /// **Height must not come from `.frame(minHeight:)`.** That is a *flexible* frame: offered more
    /// height, it grows. These sit in a band beside a hero that is `maxHeight: .infinity`, so on a
    /// screen with room to spare they took a share of the surplus. Three controls split it and only
    /// looked loose, which is why it went unnoticed; the signed-in `keep` beat has a single
    /// Continue, and that one control stretched to 86pt and ran off the bottom of the screen.
    /// `.fixedSize` on the band did not help, because the flexibility is in the control itself.
    /// Padding gives a height that still grows with Dynamic Type but cannot be stretched.
    ///
    /// The horizontal padding is applied *before* `.frame(maxWidth: .infinity)`, so the proposed
    /// width reaches the text already inset. The other way round, the label runs the full width of
    /// the button, and at larger text sizes "I already have one" touched its own border.
    private func primary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(BrandFont.ui(16, weight: .bold))
                .foregroundStyle(primaryLabel)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .frame(height: primaryHeight)
                // `ignoresSafeAreaEdges` defaults to `.all`, which is right for the full-bleed
                // bands and wrong for a control. Left at the default, the fill bled through the
                // bottom safe area to the edge of the screen: on the signed-in `keep` beat, where
                // Continue is the only control and sits next to that edge, a 52pt button painted
                // an 88pt block that ran off the bottom. The frame was correct the whole time,
                // which is why a minimum height, `fixedSize` and even a definite height all failed
                // to change it. Only the paint was wrong.
                .background(primaryFill, ignoresSafeAreaEdges: [])
        }
        .buttonStyle(.plain)
    }

    private func secondary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(BrandFont.ui(16, weight: .bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .frame(height: secondaryHeight)
                .overlay { Rectangle().stroke(actionForeground, lineWidth: 1.5) }
        }
        .buttonStyle(.plain)
    }

    private func quiet(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(BrandFont.ui(15, weight: .medium))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.75)
            .opacity(0.75)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
                .frame(height: quietHeight)
    }

    // MARK: - Actions

    /// Leaving the account ask, from any of its three answers.
    ///
    /// The plan beat is skipped for an account that is already paying, using a value fetched
    /// *ahead* of this moment rather than at it. The first version awaited `GET /api/me` inside the
    /// button's action, which had two failure modes and hit both: on a paid account onboarding
    /// simply ended with no pricing screen, and while the request was in flight the button did
    /// nothing at all, so a slow or hung network made Continue look dead. Neither is acceptable for
    /// a control somebody has just pressed.
    ///
    /// Deciding from state makes this synchronous and total: known-paid skips, everything else,
    /// including "not known yet" and a failed request, shows the offer. Being pitched something you
    /// already own is a smaller harm than a button that does nothing.
    private func advanceFromAccountAsk() {
        if isPaidAccount == true, !Self.isForcedForDemo {
            onComplete()
        } else {
            advance(to: .plan)
        }
    }

    /// `-show-onboarding` replays the flow for development and for filming it. The entitlement skip
    /// is suppressed under it, because the person running the flag is the person who owns the Pro
    /// account, and silently dropping the pricing screen is exactly what they are trying to look at.
    private static var isForcedForDemo: Bool {
        ProcessInfo.processInfo.arguments.contains("-show-onboarding")
    }

    /// The plan beat's primary action.
    ///
    /// It routes through `ProStore` so that wiring StoreKit later is a new conforming type rather
    /// than a change here. The placeholder answers `.notConfigured`, which finishes onboarding,
    /// which is exactly what this button did before the seam existed.
    private func buy() {
        let product: ProProduct = chosenPlan == .annual ? .annual : .monthly
        Task {
            switch await ProStoreRegistry.current.purchase(product) {
            case .purchased, .notConfigured, .pending:
                onComplete()
            case .cancelled:
                break
            case .failed:
                // Nothing is surfaced yet because nothing can fail yet. When `StoreKitProStore`
                // lands this needs a message, and that is part of wiring it.
                break
            }
        }
    }

    private func advance(to destination: Beat) {
        withAnimation(OnboardingMotion.beat(reduceMotion: reduceMotion)) {
            beat = destination
        }
    }

    /// Recolours the live palette under the words. `recolor(to:)` rather than `replace(with:)` so
    /// each band keeps its slot identity and the colour animates in place instead of the band being
    /// torn down and rebuilt.
    private func choose(_ mood: OnboardingMood) {
        chosenMood = mood
        AnalyticsService.capture(.onboardingMood, ["mood": mood.rawValue])
        withAnimation(PaletteMotion.replace(reduceMotion: reduceMotion)) {
            store.recolor(to: mood.colors)
        }
    }

    /// Leaving early must not cost the reader a palette they already had. Once they have pressed
    /// "Keep this one" the mood is a decision they made, so it stays.
    private func skip() {
        if beat != .keep, let restorePalette {
            store.recolor(to: restorePalette.colors)
        }
        finish(.later)
    }

    /// Notes how the account beat was answered. The event is sent here rather than at the very
    /// end so it still lands if the reader leaves on the plan screen.
    private func record(_ answer: OnboardingExit) {
        exit = answer
        AnalyticsService.capture(.onboardingChoice, ["exit": answer.rawValue])
    }

    private func finish(_ answer: OnboardingExit) {
        record(answer)
        onComplete()
    }
}
