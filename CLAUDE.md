# ColorSense iOS — Project Context

Native iOS companion to the ColorSense web app (colorsense.online). Read this file at the
start of every session in this repo before doing anything else.

## Source of truth for brand/product facts

`/Users/chrisantomendez/Library/Mobile Documents/iCloud~md~obsidian/Documents/Daily Notes/Knowledge Base/Claude Skill.md`

That vault file owns pricing, brand colors/fonts, voice rules, and product positioning.
Don't restate or fork those facts here beyond what's needed to build — if brand colors, pricing,
or copy rules are ever needed, go read that file fresh rather than trusting a stale copy.
Any durable product/ops decision made in this repo that matters beyond code (like the
scoping decisions below) should also be reflected back in that vault file, not just here.

## Location

This repo lives at `~/Developer/ColorSense-iOS` on local disk, deliberately **outside**
Nextcloud sync. It started in the Nextcloud "ColorSense/ColorSense Mobile App Project"
folder but had to move on 2026-09-02: Nextcloud's sync raced Xcode's writes to the
`.xcodeproj` bundle and corrupted it (spawned duplicate "ColorSense 2.xcodeproj" etc. —
a known bad interaction between Xcode and any live file-sync tool, same as Dropbox/iCloud
Drive/OneDrive). A pointer note was left at the old Nextcloud path. Version control for
this project is git, not file sync — don't move it back into a synced folder.

## Onboarding is done (2026-09-04)

The first-run flow is finished, filmed and committed: splash, hello, naming, mood, keep, plan. It
was verified on a physical iPhone 17 Pro Max end to end, and swept in the simulator in dark mode, at
accessibility text sizes and with Reduce Motion on. 85 tests pass.

Four gaps are **parked on purpose** (agreed 2026-09-04), not forgotten. Three of them cannot be
closed without the paid Apple Developer Program, so they wait for it rather than being worked around.
Do not treat any of them as a bug to fix in isolation.

**Blocked on developer access.** These join the list under "Distributing to testers" below, which is
the canonical account-side checklist. When enrolment completes, work that list, not this one.

1. **The plan beat does not purchase anything.** `Services/ProStore.swift` is the seam and carries
   the step-by-step wiring checklist. Guideline 3.1.1 makes a purchase screen that cannot purchase a
   rejection risk on its own, so before any build is submitted this must be wired **or** hidden.
   Hiding it is one line, because `advanceFromAccountAsk()` already routes past the beat.
2. **Sign in with Apple is still unprovisioned**, and guideline 4.8 requires it wherever a
   third-party sign-in is offered. The account beat offers Google today, so the account screen is a
   rejection on its own until Apple is enabled for the App ID and on the production Clerk instance.

**Not blocked, and can move at any time.**

3. **The trial is not in the vault.** `Claude Skill.md` section 3 lists Pro Monthly $5, Pro Annual
   $39 and the $9 Pro Pass, with no trial of any length. Configuring it needs App Store Connect, but
   *deciding* it does not, and the app currently shows a 7-day trial the source of truth does not
   mention. Reconciling that is a vault edit, not an Apple one.
4. **The asset catalog is about 20MB**, nearly all of it the three Lauma clips at roughly 4.5MB each.
   Fine now. Worth a decision before a fourth clip, and the lever is frame height, not frame count.

## Status (as of 2026-09-02)

Verified end to end: `xcodegen generate` produces a working project, `xcodebuild build`
succeeds, `xcodebuild test` passes all 5 `ContrastCalculatorTests` (Swift Testing
framework, not XCTest), and the app launches and renders in the iOS 17 simulator
(screenshot confirmed the Extractor tab, coral button, tab bar). This was a real
build/run, not just "code looks right" — three actual bugs were found and fixed doing it:

1. **`ExtractorViewModel.swift`** — `Task { await loadAndExtract() }` inside a `didSet`
   captured non-isolated `self`, which Swift 6's strict concurrency checker correctly
   flagged as a data-race risk. Fixed by marking the whole class `@MainActor` (the
   standard pattern for SwiftUI view models under Swift 6), not just the method.
2. **`project.yml`** — the `ColorSenseTests` target had no `GENERATE_INFOPLIST_FILE`
   setting, so `xcodebuild test` failed at the code-signing step. Added
   `GENERATE_INFOPLIST_FILE: YES` to that target's settings.
3. **`AppConfig.swift` / `ColorSenseApp.swift`** — the original `assertionFailure` on a
   missing Clerk key crashed the whole app (and thus the test target, which launches it)
   before any test could run. Clerk's own SDK also traps if `Clerk.shared` is touched
   without `configure()` ever being called, and `configure()` itself validates the key's
   *format* locally (not just non-empty) before any network call. Fixed by: making the
   missing-key case a `print` warning instead of a crash, and having it return a
   syntactically-valid-but-fake key (`pk_test_` + base64 of
   `"colorsense-dev-placeholder.clerk.accounts.dev$"`, matching Clerk's real key shape)
   so `configure()` succeeds locally. Sign-in will still fail once it tries to actually
   reach that fake host — which is correct, since there's no real key yet.

Since then (all verified on a physical iPhone 17 Pro Max, iOS 26.6.1): the real production
`CLERK_PUBLISHABLE_KEY` is set, email sign-in works, saving a palette to the account works and
shows up on colorsense.online, the brand fonts are in, and the app icon is wired.

Still open:
- **Sign in with Apple** — the native entitlement is attached to Release in `project.yml`; Apple still needs
  to be enabled for the `online.colorsense.ios` App ID and on the existing production Clerk
  instance. ClerkKitUI's `AuthView` will show it automatically once the provider is enabled.
- **Google sign-in works** — `online.colorsense.ios://callback` is allowlisted on the production
  Clerk instance and was verified end to end on Chris's physical iPhone.
- **`clerk.colorsense.online` fails TLS** — worked around by the proxy on both platforms, but
  worth a Clerk support ticket. See "Auth" below.
- **No StoreKit**, so Subscription is read-only and the web's AI-harmonies Pro button is absent.

## Scoping decisions (locked in 2026-09-02)

These were deliberately decided with Chris and shouldn't be re-litigated without cause:

- **Waitlist gate overridden.** The vault's Claude Skill.md previously said "PWA-first,
  30+ waitlist signups before native build" (was at 4 signups). Chris chose to proceed
  with native now; the vault file has been updated to match. If you're reading this and
  the vault still says otherwise, that's a bug — reconcile it.
- **MVP scope: Extractor + WCAG Contrast Checker only.** Both are the two tools the web
  app treats as always-free/unlimited/no-signup — natural pairing for v1. Brand Kit
  Creator, Palette Health Score, Website Color Analyzer, and Color Scheme Generator are
  cut from v1, not cut forever.
  - Do not add new tool screens without an explicit ask — that's a scope decision, not
    a code decision.
  - **Amended 2026-09-04: the rest of the cut list is being brought in, in a decided order.**
    Asked for directly, so this is an amendment rather than drift, and the vault should say so. The
    order is SVG Recolor, then Website, then Visualizer, then Schemes, with Brand Kit last. SVG
    Recolor has landed. Each is a **port of its lab panel**, not of the standalone marketing page,
    because the panels are the ones that act on the current palette, which is the model this app
    uses. This does not reopen "no tab bar" or "no landing screen": they are `Tool` cases reached
    from the Tools sheet, exactly as Health is.
  - **Amended 2026-09-03: Palette Health was added, reversing the half of this that cut it.**
    Asked for directly, so it is an amendment rather than drift — the vault's `Claude Skill.md`
    should say so too. The rest of the cut list still stands: Brand Kit Creator, Website Color
    Analyzer and Color Scheme Generator are still out, and still need an explicit ask.
  - Health is a **port**, not an invention. `Services/PaletteHealth.swift` is `scorePalette()` from
    the web's `lib/paletteHealth.ts`, and `Services/PaletteHealthReport.swift` is
    `buildHealthReportData()` from `lib/paletteHealthReport.ts`. The report pulled in a third
    port, `Services/ColorBlindness.swift` from `lib/colorBlind.ts` — the Machado (2009)
    simulation and the ΔE confusable-pair check.
  - **No PDF export**, unlike the web. That is a desktop deliverable and the web app already does
    it well; a phone is not where anyone assembles a client PDF.
- **Amended 2026-09-03: first launch is a full-screen onboarding flow, and iOS asks for an
  account.** This does not reopen "no landing screen": the flow is made of bands and hands the
  palette straight back, and there is still no separate upload or landing screen. It does change
  two things. First launch no longer always lands on `brandDefault`; the reader picks a mood and
  keeps it. And the "free, unlimited, no signup" promise is **removed from the iOS app**, which
  contradicts the vault's positioning and needs reconciling there. See "Onboarding, and Lauma".
- **Build approach: fresh native SwiftUI**, not a WebView wrapper. Color extraction and
  WCAG math are reimplemented natively in Swift (see below), not proxied to the web app.
- **Backend: offline-first / on-device.** The extractor and WCAG checker do no networking
  at all. This matches the "free, unlimited, no signup" positioning from the vault. The only
  networking is Clerk auth and `SavedPaletteService` (saving a palette to the user's account),
  both of which are opt-in and never block a tool.
  - **Amended 2026-09-03: analytics were added, reversing the "no networking at all" half of
    this.** PostHog product analytics now run for every user, signed in or not. Chris asked for
    it deliberately, knowing it contradicts the positioning above; the vault's `Claude Skill.md`
    should say so too. The constraints that keep the reversal narrow live in
    `Services/AnalyticsService.swift` and are the point of that file: pseudonymous with `identify()`
    never called, no session replay or interaction autocapture, and an outbound allowlist containing
    only the closed product-event enum plus PostHog's `$exception` crash event. Fatal crash reports
    contain stack traces and technical diagnostics, but no breadcrumbs, logs, hex values, palette
    names or photos. The opt-out in Account calls PostHog's own
    `optOut()`, verified to stop the SDK rather than merely skipping call sites: zero connections
    to `us.i.posthog.com` while opted out, against a live one while opted in. The tools themselves
    still do their actual work — extraction and WCAG math — entirely on device.
  - PostHog ships **its own privacy manifest**, unlike Clerk and Nuke, so its required-reason APIs
    and its product-interaction/usage declarations are not repeated in ours. Apple aggregates
    every manifest in the bundle. Note it declares collection as *unlinked*, which stays true only
    while `identify()` is never called — identifying users would silently make PostHog's own
    declaration false.
  - The package is declared in `project.yml`, not through `npx @posthog/wizard`. The wizard writes
    into the generated `.xcodeproj`, which is gitignored and rebuilt by `xcodegen generate`, so
    its changes disappear on the next generate.
- **"Save" and "Share" mean different destinations** (clarified 2026-09-02). *Save to my
  account* posts to `/api/saved-palettes` — the same store the web app writes to, requires
  sign-in. *Share as image* / *Save image to Photos* hand the palette to the **device**. Do not
  relabel these into one another; Chris corrected this specifically.
- **Auth: Clerk, wired from day one**, tied to the same Free / Pro Monthly ($5/mo) /
  Pro Annual ($39/yr) / Pro Pass ($9 one-time) plans as the web app, even though v1's
  own tools don't gate on it. This is forward-positioning for when Pro features
  (e.g. Brand Kit Creator, AI brand analysis) land on iOS.
- **Design: follow the web app's mobile layout** (decided 2026-09-02, supersedes the earlier
  "no mockups exist, design from the brand kit" note). Chris supplied mobile screenshots of
  colorsense.online; the palette screen matches them — full-bleed color bands splitting the
  screen, large mono hex, ntc color name beneath, label color flipping per swatch via
  `ContrastCalculator`.
- **One palette, many tools** (decided 2026-09-02, replaces the original tab-bar navigation).
  The app *is* the current palette; there is no tab bar and no landing/upload screen. Tools
  are actions on that one palette, reached from a collapsed Tools sheet — the model the web
  app states outright in its own Tools sheet ("All work on the same palette"). A sheet was
  chosen over tabs specifically so the tool list can grow past the three or four items a tab
  bar tolerates. `PaletteStore` owns the palette; `RootView` is the screen.
- **All chrome is one floating glass dock** (decided 2026-09-02, from a reference Chris supplied).
  Share · Tools · **+** · Generate · Account, icon-only, in a single `.ultraThinMaterial` capsule.
  There is no navigation bar — once every action moved into the dock, the bar held only a title,
  which was not worth a full bar of chrome. The centre **+** is the only coral item; an icon-only
  row needs exactly one focal point, and giving Generate a second accent left neither reading as
  primary. Bands run full-bleed under the status bar; iOS was observed adapting the status bar
  between light and dark automatically (verified on both a near-black and a coral first swatch),
  so don't add a manual override unless a real device proves otherwise.
- **The app opens on the user's last palette** (asked for 2026-09-02). Persisted as JSON to
  Application Support. First launch lands on `ExtractedPalette.brandDefault` (the brand kit
  colors), never an empty state. This reverses the earlier "no persistence in v1" position —
  only the *current* palette is stored; a saved-palettes Library is still out of scope.
- **The current palette is directly editable from 1–8 colors** (asked for 2026-09-02). Small
  seam controls insert either a custom color or a named color from the user's account; trash
  removes a swatch and offers Undo. A reusable saved color is deliberately represented by the
  existing `/api/saved-palettes` contract as a named one-swatch palette, keeping it compatible
  with the existing Clerk account and web Library without adding a second storage system. The
  custom editor starts with a blend of the two colors around the selected seam and provides the
  native Grid/Spectrum/Sliders picker plus a validated, paste-aware six-digit hex field.
- **Generate is a port of the web's `relatedPalette()`** (decided 2026-09-02, replaces an
  earlier drift-from-previous implementation). Every tap re-derives from *anchors* — the locked
  swatches if the user has locked any, otherwise the original extract — with `iteration`
  selecting the hue scheme. Iterations 0-9 cycle tight schemes (monochromatic, analogous,
  complementary); from 10 the pool widens to triadic/split-complementary/broad with bigger
  jitter. There is no cap and no countdown in the UI: the run never dead-ends, so a number
  would be noise. This mirrors `shuffle()` in the web's LabContext.tsx exactly.
  Note this is adjacent to the Color Scheme Generator tool that "MVP scope" above cuts — it
  was requested directly and is a control on the existing palette, not a new tool screen.
  It does not reopen the rest of that scope decision.
- **Locking steers generation.** A locked swatch survives Generate and becomes an anchor for the
  regenerated ones. Lock state persists with the palette.
- **Minimum iOS version: 17.0.** Not asked explicitly — chosen because the Clerk iOS SDK
  itself requires iOS 17+, so there was no lower option once Clerk was in scope.

## Architecture

```
ColorSense/
  App/              ColorSenseApp.swift (entry point, Clerk.configure, owns PaletteStore), AppConfig.swift
  DesignSystem/      BrandColor.swift, BrandFont.swift, SpeechBubble.swift — brand kit as Swift, not hardcoded per-view
                     CustomColorEditor.swift  the one hex field and colour wheel, shared by every
                                              screen that lets somebody enter a colour
                     LaumaStage.swift  the mascot's poses; lives here, not under Onboarding, because
                                       she is brand and is now used across the app
                     LaumaNotice.swift the one way an empty, failed or refused screen speaks
  Models/            PaletteColor, ExtractedPalette (+ .brandDefault, .sample)
  Services/
    ColorNameService.swift   Nearest Name That Color match
    PaletteStore.swift       THE palette: current state, generation count, JSON persistence
  Features/
    Home/
      RootView.swift         The app's only screen — bands + Tools/Generate bar + nav actions
      ToolsSheet.swift       Collapsed tool picker; add a `Tool` case to add a tool
    Palette/
      PaletteBandsView.swift Full-bleed bands, tap to copy
    Extractor/
      PhotoExtractor.swift   PhotosPickerItem -> palette (an action, not a screen)
      ColorExtractionService.swift  On-device k-means
      PaletteGenerator.swift Drift for Generate, plus the fresh-palette suggestion
      PaletteExportService.swift    Hex list / CSS vars / shareable PNG
    Onboarding/
      OnboardingFlowView.swift  The six-beat first run, built out of palette bands
      LaumaClip.swift           Her animated clips, cut from video; first run only
      LaumaBlink.swift          The splash blink, ten frames driven by the clock
      OnboardingMood.swift      The four starting palettes offered in beat three
    SvgRecolor/
      SvgRecolorView.swift  Open an SVG, map its colours onto the palette, export it
      SvgPreview.swift      WKWebView, JavaScript off, no network: iOS cannot draw SVG natively
    WCAGChecker/      ContrastCalculator (WCAG 2.x luminance) + a sheet seeded from the palette
    Auth/             AccountView wraps Clerk's AuthView/UserButton, presented as a sheet
  Resources/
    Assets.xcassets/  AppIcon (needs a real 1024x1024 icon — placeholder slot only), AccentColor (set to Coral)
    ColorNames.json   1,566 ntc color names, ported from the web app — see "Color names" below
    Fonts/            EMPTY — see "Fonts" below, this is a manual step
ColorSenseTests/
  ContrastCalculatorTests.swift   WCAG math against known values (black/white = 21:1, etc.) plus
                                  band-label checks pinned to what the web app renders
  PaletteGenerationTests.swift    Drift bounds over a full 10-generation run, the generation cap,
                                  and store persistence across simulated relaunches
Scripts/
  run-sim.sh        Build + install + launch + screenshot on a simulator, one command
```

## Running on a physical iPhone

The simulator signs locally and needs no Apple account. A real device needs a signing team,
which `project.yml` reads from `DEVELOPMENT_TEAM` in `Config/Secrets.xcconfig` — so it is never
committed, and `xcodegen generate` does not wipe it the way editing Xcode's Signing tab would.

1. Xcode ▸ Settings ▸ Accounts ▸ **+** ▸ Apple ID. A free Apple ID is enough; it creates a
   "Personal Team".
2. Copy the 10-character Team ID from that account's team list into `Config/Secrets.xcconfig`
   as `DEVELOPMENT_TEAM = ...`, then re-run `xcodegen generate`.
3. Connect the iPhone by cable, unlock it, tap **Trust This Computer**.
4. Pick the device in Xcode's run destination menu and hit Run.
5. First launch only: on the iPhone, Settings ▸ General ▸ VPN & Device Management ▸ trust the
   developer certificate.

Constraints worth knowing before promising anything:
- The device must be on **iOS 17 or later** (the deployment target, driven by Clerk's own minimum).
- A **free** Apple ID signs for **7 days**, then the app stops launching until it is rebuilt from
  Xcode. A paid Developer Program membership ($99/yr) extends that to a year and unlocks TestFlight.
- Haptics only exist on hardware — the simulator has none, so device is the only way to check them.
- Sign-in and account-saved palettes *do* work on device — the real production
  `CLERK_PUBLISHABLE_KEY` is in `Config/Secrets.xcconfig` and was verified end to end.

## Distributing to testers — what is ready and what is not (2026-09-03)

Nothing can reach a tester remotely yet. TestFlight requires the paid **Apple Developer Program
($99/yr)**; a free Personal Team has no App Store Connect access at all, so the only install path
today is a cable and Xcode, expiring after 7 days. Enrol as an *Individual* for a fast turnaround,
or as an *Organization* (needs a D-U-N-S number, roughly a week) if the store listing has to say
"ColorSense" rather than a personal legal name — the type cannot be changed later without
re-enrolling.

Once enrolled: **internal** testers (≤100) skip Beta App Review and get builds in minutes, but each
one needs a real App Store Connect role. **External** testers (≤10,000, invited by email or public
link) need no team access but cost a Beta App Review per significant build. Builds expire after 90
days either way.

The repo side is done as far as it can go without an account:

- **Privacy manifest** — `ColorSense/Resources/PrivacyInfo.xcprivacy`, copied to the bundle root.
  It covers the whole package graph, not just our code: of the three packages that ship in the
  binary, only PhoneNumberKit carries its own manifest, while ClerkKit/ClerkKitUI 1.5.1 and Nuke
  ship none — and SPM links them statically, so their API use is ours to declare. Hence the
  UserDefaults entry (Clerk's install marker and last-used-auth cache) and the file-timestamp
  entry (Nuke's `DataCache` LRU eviction; Nuke arrives transitively via ClerkKitUI's avatars).
  **Re-check this whenever a package version moves.** Apple's scan only runs server-side at
  upload, so this cannot be validated locally — the first upload is the real test.
- **No Clerk telemetry ships.** `TelemetryCollector.shouldRecord()` returns false with reason
  "production instance", and we ship a `pk_live_` key. Pointing the app at a *development* Clerk
  instance would start it flowing and would make the manifest wrong.
- **Version numbers are wired, and were silently broken before.** `GENERATE_INFOPLIST_FILE: NO`
  means Xcode never injects `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`, so XcodeGen's own
  defaults (1.0 / 1) were winning and both settings in `project.yml` did nothing. The plist now
  reads `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)` explicitly. Bump
  `CURRENT_PROJECT_VERSION` on **every** upload — App Store Connect rejects a reused build number.
- **App icons are upload-safe** — both 1024×1024, PNG colour type 2, no alpha channel. Apple
  rejects an App Store icon with alpha, so re-check with the IHDR if the icon is ever replaced.
- **No purchase copy anywhere in the app.** Guideline 3.1.1 covers prose, not just buttons, so
  `SubscriptionView` and `ShareSheet` name the Pro tier without naming where to buy it. The
  affiliate link in `AffiliateView` is deliberately untouched: applying to a referral programme is
  not a digital-goods purchase.

Still blocked on the paid account, and this is the canonical list: registering the
`online.colorsense.ios` App ID, provisioning Sign in with Apple, the App Store Connect record and
its privacy questionnaire, and the archive itself (`xcodebuild archive` needs a distribution
certificate). Onboarding added two more (see "Onboarding is done" at the top of this file):

- **Create the two Pro subscriptions** in one subscription group, with the identifiers in
  `ProProduct`, attach the trial as an introductory offer on the monthly one, then write
  `StoreKitProStore` and point `ProStoreRegistry.current` at it. Add a Restore Purchases control at
  the same time; App Review requires one for auto-renewable subscriptions and there is deliberately
  no dead button for it today.
- **Enable Apple for sign-up and sign-in** on the production Clerk instance and register the Team ID
  and bundle ID as a Clerk Native Application, so the onboarding account ask satisfies guideline 4.8.

### PostHog open items before the first beta release (added 2026-09-04)

The app integration and the pinned **iOS Retention & Reliability** dashboard are configured. The
PostHog project also has exception autocapture enabled. These release-only tasks remain:

1. **Complete and publish the App Store Connect App Privacy answers.** They must match the app and
   every bundled SDK, including PostHog and PHPLCrashReporter: Product Interaction and Other Usage
   Data for analytics, plus Crash Data and Other Diagnostic Data for crash diagnosis. PostHog uses
   only its random installation ID here; these four categories are not used for tracking and are
   not linked to the Clerk account. Keep the existing linked Clerk/user-content declarations too.
2. **Add and verify PostHog's Release dSYM upload build phase.** Use the SPM script at
   `"${BUILD_DIR%/Build/*}/SourcePackages/checkouts/posthog-ios/build-tools/upload-symbols.sh"`,
   keep Release set to `DWARF with dSYM File`, authenticate `posthog-cli`, and do not enable
   `POSTHOG_INCLUDE_SOURCE`. Without the matching dSYM, native crash addresses will not become
   useful symbolicated ColorSense stack frames.
3. **Smoke-test the actual archived build before inviting beta testers.** Confirm the Release
   archive contains the production PostHog project token and host, launch it with analytics enabled,
   and verify `app_opened` reaches the dashboard. Then trigger one controlled crash in an internal
   test build, relaunch so the stored report uploads, verify `$exception` appears in Error Tracking
   and both reliability tiles, and remove any temporary crash trigger before external distribution.
4. **Check the uploaded privacy report and monitoring once App Store processing finishes.** Treat
   Apple's server-side privacy-manifest report as the authoritative aggregation, resolve any warning,
   and confirm the dashboard's four tiles still query the production project. Retention will remain
   sparse until at least a second weekly cohort interval has elapsed; that is expected, not a setup
   failure.

One thing to fix *outside* this repo before external testing: the web privacy policy at
`/privacy-policy` never mentions mobile or iOS. It is substantively accurate — same Clerk instance,
same API, same data — but a reviewer checks that the policy covers the app. Deliberately parked
until the Replit side is being touched anyway.

## The primary button, and the one place the app fails its own checker

`DesignSystem/PrimaryActionButton.swift` is the house primary action: full width, 15pt medium,
14pt vertical padding, white on CORAL, 13pt radius. `SavePaletteView` and `ColorDetailView` had
already converged on exactly this and spelled it out twice; SVG Recolor then arrived using
`.borderedProminent` with a coral tint, which is the *system* button and differs in padding, radius,
font and label colour. It is now one named style and every primary action uses it. **Do not reach
for `.borderedProminent`**: it looks close enough to pass review and is wrong in four ways at once.

**The white label is a house choice, not a measured one, and the app's own tool disagrees with it.**
Measured through `ContrastCalculator` rather than by hand:

| label on CORAL | ratio | `ContrastCalculator.rating` |
|---|---|---|
| white (shipping) | 2.78 | **POOR 2/5** |
| black | 7.57 | GREAT 5/5 |

So the primary button in a contrast-checking app is rated POOR by that same checker, and
`legibleForeground` would pick black. This is deliberate for now rather than unnoticed: it is the
established look, it matches the web, and changing it alters five buttons and the brand's feel, so
it is Chris's call and not a silent fix. Note the onboarding beats already *do* invert to the band's
measured ink, so the app is currently inconsistent with itself on this point. If the answer is ever
"make it pass", the change is one line in `PrimaryActionButtonStyle`.

## Measuring UI alignment

Icon alignment complaints have come up twice and eyeballing got it wrong both times — one
"fix" moved a glyph further out of line. Measure instead:

```bash
sips -s format bmp --cropToHeightWidth <h> <w> --cropOffset <top> <left> shot.png --out c.bmp
```

then parse the BMP in Python (no PIL on this machine), threshold the dark pixels, group them
into columns per glyph, and compare each glyph's bounding-box centre. Screenshots are 3x, so
divide pixel deltas by 3 for points.

Two things that matter and are easy to get wrong:
- Size SF Symbols by **point size**, not by scaling each into an identical box. They are drawn
  to look balanced at a common point size; normalising bounding boxes renders tall glyphs (like
  `square.and.arrow.up`) visibly narrower than the rest.
- A residual offset remains because a symbol's *ink* can sit off-centre inside its own layout
  box. That is what `DockIcon.opticalOffset` is for — one measured value per symbol, with the
  measurement recorded in a comment, never a guess.

## Checking Dynamic Type, dark mode and orientation (swept 2026-09-03)

The simulator can be driven from the shell, which is how the accessibility sweep was done:

```bash
xcrun simctl ui booted appearance dark|light
xcrun simctl ui booted content_size accessibility-extra-large   # note the UNDERSCORE
```

Rotation has no `simctl` equivalent — go through the menu instead, which is reliable:

```bash
osascript -e 'tell application "System Events" to tell process "Simulator" to \
  click menu item "Portrait" of menu 1 of menu item "Orientation" of menu 1 \
  of menu bar item "Device" of menu bar 1'
```

Sheets can be opened without a UI test target: the Simulator publishes the app's accessibility
tree, so a click at a screen coordinate lands on a real control. Read the device screen's origin
and size off `group 1 of window 1` (`position`/`size` via System Events), then a device point maps
to `origin + point`. The dock sits at y=808pt, with Share/Tools/+/Generate/Account at x=64/132/201/269/337.

Two traps worth knowing before trusting a screenshot:
- **`simctl io screenshot` always writes the framebuffer in the device's *native* portrait size.**
  A rotated device gives a portrait-shaped PNG with sideways content — rotate it with
  `sips -r 270` before reading it, or you will misread the layout entirely.
- **A blank white frame is launch lag, not a crash** (see "Running the app"). Allow ~11s after
  `simctl launch` before capturing, and longer than that after a fresh install.

**What cannot be done this way: scrolling.** The Simulator exposes no `AXScrollArea`, and there is
no Quartz in the system Python to synthesise wheel events, so anything below the fold has to be
checked on a device by hand. That is the one thing worth keeping a device around for.

Measure rather than eyeball, the same rule as "Measuring UI alignment" above. Sampling a column of
pixels out of a BMP and reading where the colour changes gives exact band heights, and that is what
finally identified the landscape overflow as the 44pt tap targets rather than the type — after two
fixes had been aimed at the wrong constraint.

Results of the sweep, all confirmed on a physical iPhone 17 Pro Max:

- Fixed: `BrandFont.mono` did not scale, the palette bands clipped names, the dock painted its
  glyphs against the system appearance instead of its swatch, and the Tools and Share grids broke
  words mid-way at accessibility sizes.
- **Checked and found fine, so do not "fix" them:** the Conversion and Harmonies grids in
  `ColorDetailView`, and the saved-colors grid in `AddColorView`. They keep fixed column counts on
  purpose — `AdaptiveColumns` is not needed there.
- Added 2026-09-03: **`Move up` / `Move down` accessibility actions on each band.** Drag-to-reorder
  had no VoiceOver equivalent at all, so the palette's order was simply not editable with the
  screen reader on — the same gap the delete action had already been given a fix for. Onboarding
  asking every reader to reorder a band is what turned it from a gap into a dead end.
- Also confirmed on device: haptics (which the simulator cannot produce at all), Dynamic Type at
  large sizes, portrait lock, and dark mode over a white last swatch.

## The live camera tile, and why it crashed (fixed 2026-09-03)

`PhotoSourcePicker` shows a live viewfinder in its first grid cell. Getting that to work took
three attempts and two wrong diagnoses, so the conclusion is worth keeping.

**The cause was `previewLayer.session = session` being assigned synchronously inside
`makeUIView`/`updateUIView`.** Mutating capture-session state there re-enters SwiftUI while its
AttributeGraph transaction is still open, and the graph eventually detects a cycle and *aborts the
process*:

```
[com.apple.attributegraph:error] precondition failure: cyclic graph
```

`CameraPreviewSession.PreviewView` therefore defers the assignment by one run-loop turn, with a
generation counter to drop work for cells discarded before they reach a window. Do not "simplify"
that back into a direct assignment.

The symptom is worth recognising because it does not look like a camera bug: **every** tile in the
grid crashed, photos included, since any tap re-renders the grid and it is the *camera* cell that
makes a re-render fatal.

Two things that did **not** fix it, so they are not worth retrying:
- Owning the `AVCaptureSession` outside the view rather than in it. This is still correct and still
  in the code — it removed real session churn (`AVCaptureSession dealloc`, `Timed out waiting for
  session to stop`, `AVFoundationErrorDomain Code=-11819`) — but the cycle survived it.
- Pinning the representable's identity with `.id`. No effect at all.

Also note `CameraPreviewSession.stop(then:)` fires its completion on whichever comes first, the
stop or a 0.4s deadline. The camera cell releases the camera before presenting the capture screen,
and `stopRunning()` can block ~9 seconds when the session is wedged — measured — which would
otherwise be a nine-second wait before the camera appears.

**The simulator cannot verify any of this visually.** Its synthetic camera logs `Timed out waiting
for session to start` and never runs the session, so the tile stays black there no matter what.
The crash is reproducible in the simulator, but only with camera permission already granted
(`xcrun simctl privacy booted grant camera online.colorsense.ios`) — without it the tile falls back
to a glyph and nothing churns. A working preview can only be confirmed on device.

One more red herring: `ClosedViewfinderController: Viewfinder still closed …` appears in simulator
logs whether or not the app has a capture session at all. It is ambient noise, not a signal.

## Onboarding, and Lauma (rebuilt 2026-09-03)

First launch is a **full-screen flow built out of the app's own palette bands**. No cards, no
scrim, no gradient.

The first attempt was a gradient backdrop with rounded translucent cards, and Chris's verdict was
that it felt generic with none of ColorSense's personality. He was right, and the diagnosis is
worth keeping: it covered the palette in order to show a tutorial *about* the palette. Full-bleed
color bands with hard edges and Bebas set directly on the color are the one thing that makes this
product look like itself, and the old design hid exactly that behind the house style of every SaaS
onboarding. If a future change starts reaching for a floating panel over the bands, that is the
same mistake.

The screen is a tall hero band carrying the type, three colour strips, and an action band at the
bottom. Every label takes its colour from the band it sits on through `legibleForeground`, the same
`ContrastCalculator` route every swatch label uses, so nothing here needed a hand-picked colour.

Three beats:

0. `splash` holds the launch screen's own composition, same pose on the same coral, for 1.15s and
   then advances itself. It exists because **nobody ever sees the system launch screen**: iOS
   caches the launch snapshot per install, so an upgrade keeps showing the previous one, and on a
   fast device it is gone in a frame or two anyway. Chris reported the first screen simply never
   appeared. This makes the brand moment land without costing a tap.
1. `hello` a flat **TEAL** field, Lauma centred, one speech bubble reading "HI! I'm Lauma." and
   nothing else. No wordmark, no headline, no supporting paragraph (Chris asked for the lockup and
   the extra copy to come out; the launch screen already showed her face and the next beat carries
   the product idea). Three things here are deliberate and easy to break:
   - **The bubble is DM Sans, not the Bebas display face.** Bebas Neue is caps-only, so it renders
     "I'm Lauma" as "I'M LAUMA" and destroys the casing the line is written in.
   - **The strips collapse to zero height on this beat only.** They are the same teal as the hero
     so they show nothing, but at 84pt each they still took 252pt out of the band, which pushed
     her a full 126pt above the centre of the screen she is meant to stand in the middle of.
   - **The bubble is glass** (`.ultraThinMaterial`) with `.primary` text, so it follows the system
     appearance. It was a solid black fill first, which Chris queried for dark mode. Worth knowing:
     that version was not actually broken, because the flow paints explicit brand colours and so
     renders identically in both appearances. Glass is a style choice, not a bug fix.
2. `naming` a flat **CORAL** field with Lauma on top and the type underneath, the same vertical
   order as the introduction before it so the two screens read as one sequence. She was
   bottom-right with left-aligned type first, which put her in competition with the headline for
   the same corner and made the two screens feel unrelated. Its strips collapse to zero for the
   same centring reason as `hello`. It and it labels itself the way the app labels a swatch: "Bittersweet"
   over "#FF6B6B". That name is the real Name That Color match, verified against `ColorNames.json`
   rather than written from memory.
3. `mood` the same five slots animate from coral to a real palette, so the field appears to
   **split**. Picking a mood recolors them live underneath. The split is the product demo; no copy
   explains it. The four moods are rendered as miniature palettes, not icon-and-subtitle rows.
   **Lauma's pose changes with the mood picked** (`OnboardingMood.pose`), so she reads as reacting
   to the choice. That mapping is restricted to the full-body poses on purpose: the expression
   busts are framed at the chest, so mixing them in at one height makes her jump scale between
   selections. A full-body emotion set would let this be much more expressive; see below.
4. `keep` the palette is theirs, and the account ask lands here, after they have made something.

Lauma's placement is per beat and was iterated on with Chris. `hello` and `keep` stand her on the
seam at the bottom of the hero band as a `bottomTrailing` overlay; her height on `hello` is capped
at 200 because a taller pose reaches up and clips the headline's last character. `mood` is
different: she is an **inline sibling** in an HStack beside the question, using the GUIDE pose
**flipped** so her arm points back at the four choices. Pinned to a corner there she floated in the
empty top of the band with nothing tying her to the words, and unflipped she pointed off the edge
of the screen. Her column narrows the type, which is why that headline is the short one.

Load-bearing details:

- **`PaletteStore.recolor(to:)`, not `replace(with:)`.** `replace` mints fresh swatch ids, so the
  bands are torn down and rebuilt and the colors *pop*. `recolor` carries each slot's id, which is
  what lets the mood preview morph. It also resets the generation run and re-anchors.
- **Backing out before "Keep this one" restores the palette that was on screen**, so the dev-only
  `-show-onboarding` flag can never eat real work.
- The drag-to-reorder lesson was **cut** on purpose (2026-09-03). "Now press and hold a band" was
  the most tutorial-shaped moment in the flow and the main thing that read as generic. The
  `LaumaPaletteTip` component that supported it was deleted rather than left dead.
- **The primary button inverts its band** (settled 2026-09-04, after two rejected attempts). It is
  filled with the band's own measured ink and labelled in the band's colour: a black bar with TEAL
  type on the teal field, CORAL type on the coral one. Three treatments were tried in order, and
  the two dead ends are worth not repeating. Plain `actionForeground` made the flow read as black
  bars on flat colour. Filling with a second brand colour instead (CORAL on TEAL, TEAL on CORAL,
  YELLOW on BLURPLE) fixed that but made the button an unrelated third colour whose label still
  measured black, so the button and the type on the screen shared nothing, and Chris read the
  result as "a bit off". Inverting is what ties them together, and it cannot fail a contrast check:
  `legibleForeground` already picked the ink furthest from this band, so swapping the two keeps
  exactly that ratio, on a flat brand field and on whatever palette a mood turns out to be. Only
  the primary inverts; a filled second button would compete with the one meant to be pressed.
  The `plan` cards lost the YELLOW they borrowed from the old accent in the same pass, and separate
  chosen from unchosen by fill and border weight in one ink instead.
- **The splash holds five seconds** (asked for 2026-09-04). It was 1.5s, and the blink was over
  before the reader had focused on her face. `LaumaBlink` also gained a `gap` parameter and the
  splash passes a tight `0.5...1.1`, which puts a blink roughly every 1.6s, so three land inside
  the hold rather than one. This is a long hold for a screen with no controls, so if it starts to
  feel like a wait, shorten it rather than adding a skip control, which would invite a tap past the
  one moment the screen exists to show.
- **The blink is a function of the clock, and holds no state. Do not put it back on a timer.**
  Lengthening the splash did *not* make it visible on device, and the reason is the second
  occurrence of a bug this file already records once. `LaumaBlink` advanced its frames with a chain
  of `Task.sleep` calls inside a `.task` on the view, exactly the shape that silently skipped the
  splash timer before: a `.task` is tied to view lifetime, an early rebuild cancels it, `try? await`
  swallows the cancellation, and the sequence restarts from its initial delay. A phone initialises
  fast enough for that to happen repeatedly in the first seconds, which is precisely the window the
  blink plays in, so it was reset before it ever finished. The simulator is slow and idle there, so
  it played perfectly and the bug looked like a taste problem about duration.
  It is now a `TimelineView` over a pure function of `Date`: time is cut into fixed slots, each
  holding one blink at a jittered offset, so the spacing still varies but nothing is remembered
  between frames. A rebuild cannot restart, stall or desynchronise something with no state. The
  jitter is a deterministic hash of the slot index rather than `random`, because a random draw
  would answer differently on every rebuild and she would stutter mid-blink.
  Also note `shutHold`: an extra 0.1s on the fully-closed frame. Without it the blink is 420ms of
  unbroken motion that reads as a flicker, which was a real part of why it was missed.
  Verified by sampling her eye region out of simulator screenshots, not by eye: the pupil-pixel
  count drops and recovers on a ~1.6s cycle.
- **Beat content slides; the bands do not** (settled 2026-09-04, third attempt). The beats had no transition
  at all: a `switch` swaps the subtree in a single frame, so the words and Lauma cut instantly
  while the band colours and strip heights were still springing to their new values. That mismatch
  is what read as glitchy, and it is a transition bug, not a curve to retune. `.id(beat)` on the
  hero and action band makes the swap a real insertion and removal, which is the only way a
  transition can run at all, and it sits *inside* `.background(bandColors[...])` so the colour keeps
  morphing straight through. The redundant `.animation(_:value: beat)` came off the root at the same
  time, since `advance(to:)` already wraps every beat change in `withAnimation` and the second
  transaction would have overridden the transition's own timing.
  The transition itself took three goes and the two dead ends are worth not repeating. A straight
  cross-fade smears, because almost every beat has Lauma in it and two half-transparent Laumas in
  slightly different places overlap. A fade-through (outgoing leaves, then incoming arrives) fixed
  the smear but Chris still disliked it: content vanishing in place and reappearing in place reads
  as a blink rather than as motion. It is now a **slide**, old page out to the leading edge as the
  new one comes in from the trailing edge. That solves the ghosting by construction instead of
  timing around it, since the two Laumas are never in the same place, and it matches what the flow
  actually is, a sequence of pages moving forward. The flow only ever advances, which is why the
  transition is one direction and not a pair. Both bands are `.clipped()`, or the outgoing page is
  visible travelling across the strips. `OnboardingMotion.beat` is damped to 0.96, close to
  critical: a page sliding across should settle, not bounce.

### Pricing: three plans, and the trial is the highlighted one (2026-09-04)

Asked for directly, and it **reverses** the "Pro Annual is deliberately not offered here" line
below, which argued two options was the ask and a third was a conversion decision. It was made
deliberately, so it is an amendment rather than drift, and the vault should say so.

- **Yearly is on the screen at $39**, the vault's Pro Annual price. "SAVE 35%" beside it is
  arithmetic, not a claim: $5 a month is $60 a year against $39. If either price moves in the
  vault, that number moves with it.
- **The trial is now 7 days, not 14.** Still absent from the vault either way, and still a StoreKit
  introductory offer that has to be configured in App Store Connect. Shortening it does not make it
  less of a pricing decision the vault needs.
- **Each plan wears its own brand colour** and the chosen card is filled with it, rather than three
  identical outlined boxes that had to be read to be told apart. YELLOW for the trial, TEAL for
  monthly, CORAL for yearly, all from `BrandColor`. Every label on a filled card is measured with
  `legibleForeground` rather than assumed.
- **The colour stripe is an `.overlay`, not a row in the `HStack`.** As a child it was a bare
  `Color`, which is greedy for height, so it stretched the two unchosen cards about 60% taller than
  the chosen one and the three stopped reading as a set.
- **The hero scrolls at accessibility sizes.** Three cards plus the headline and the paragraph are
  taller than the band, and an overflowing hero pushed the action band clean off the bottom of the
  screen, leaving no way to subscribe *or* to dismiss. That was already true with two cards; the
  third made it obvious. The buttons survive because they live in their own band, outside the
  scroll. Verified by screenshot at accessibility-extra-large. Note CLAUDE.md's own warning that
  the simulator cannot exercise scrolling, so the scroll itself is a device check.
- The title and its badge sit side by side through `ViewThatFits` and stack once they do not fit.
  At accessibility sizes the row was too wide and the title truncated to "7 days f...", which is
  the one string on the card that has to survive.

Everything in "The plan screen is design only" below still applies unchanged: **none of this is
wired to StoreKit**, and a purchase screen that does not purchase is its own guideline 3.1.1
rejection. Adding a third plan and a discount badge raises the stakes on that, it does not lower
them.

### About, and what was deliberately left out of it (added 2026-09-04)

`Features/About/AboutView.swift`, reached from Account. Modelled on a reference design Chris
supplied (it is Coolors' About screen), but **every value comes from the vault**, not from the
reference: `hello@colorsense.online` from section 12, `@colorsensehq` from section 13, and the two
legal pages the web app actually serves.

Three rows in the reference were left out on purpose, and should stay out until each reason goes
away:

- **No Cookie Policy.** The web serves `/privacy-policy` and `/terms` and nothing else. A link to a
  page that does not exist is worse than an absent link.
- **No Support row.** The web's `/support` route renders the **Pro pricing page**. Linking it from
  inside the app is precisely the external-purchase route guideline 3.1.1 forbids, and is what got
  "Pro is available at colorsense.online" deleted already. Email reaches a person regardless.
- **No "Leave a review".** There is no App Store listing yet, so it would go nowhere. It belongs
  here the day the App Store record exists, with the real App ID.

**Feedback posts to `POST /api/feedback`**, the same route the web form uses, so a message from a
phone lands in the same table and fires the same Loops `feedback_received` event that reaches
hello@. Three things about it are load-bearing:

- **Nothing in this app talks to Loops.** `LOOPS_API_KEY` is a server secret and stays one. The app
  posts to our own API and the server does the rest. An SDK or a direct Loops call from the client
  would mean shipping that key.
- **The route takes no auth, and that is correct.** Someone whose problem *is* that they cannot
  sign in has to be able to say so, which is why `FeedbackService` deliberately does not go through
  `SavedPaletteService.authorizedRequest`. Name and email are prefilled from Clerk when there is a
  user, and typed when there is not.
- **The `website` honeypot is never sent.** The server treats any value there as a bot and silently
  accepts without recording. A native form must simply not have the field, so "add the missing
  field" is exactly the wrong instinct when reading that API later.

Client-side validation mirrors the route's own bounds (name at least 2, plausible email, message
10 to 2000) so the button gates before a round trip, and the server's written reason is shown as
returned rather than reworded, including the 429 rate-limit message.

**The portrait is looked up, not assumed.** `UIImage(named: "AuthorPortrait")` returning nil falls
back to initials, so the layout survives the asset being absent. Note the web's
`public/author-chrisanto.png` is **not** usable here: it is a Canva "Canvassador 2026" badge frame
carrying Canva's logo, and shipping a third-party mark in an About screen is wrong. The shipped
portrait is cropped from `NextCloud/ColorSense/IMG_7904.JPG`.

Two things about producing it, because both cost time:

- **Crop with `CGImage.cropping(to:)`, not `sips --cropOffset`.** Vision reports the face in image
  pixels; sips' offset convention did not agree with it and produced a picture of the ceiling three
  times running. An explicit rectangle has nothing to misread. `Scripts`-free helper lives in the
  session scratch, but the recipe is: `VNDetectFaceRectanglesRequest` for the face box, square of
  about 2.1 face-heights, eyes set slightly above centre.
- **`NSImage.lockFocus` renders at the display's scale**, so asking for 512 produced 1024 and a
  4.6MB PNG for a 72pt avatar. The asset is a **256px JPEG, 23KB**: 72pt at 3x is 216px, and a
  photograph gains nothing from PNG's lossless storage.

The social URLs are **constructed** from the `@colorsensehq` handle rather than recorded anywhere,
so they are worth checking once against the live accounts. The hero line is written for the app and
is not a vault-owned tagline; if the brand ever settles one, the vault wins.

## Every plan is listed, before any of them can be bought (added 2026-09-04)

`SubscriptionView` now lists Free, Pro Monthly, Pro Annual and the Pro Pass, with prices read from
`ProProduct` so this screen cannot drift from the onboarding plan beat or from the web. It is
**descriptive, not a shop**: nothing is tappable and nothing says where to buy, because with no
StoreKit a button would either do nothing or point outside the app. Those rows are where the buy
actions attach when `ProStore` goes live.

**The Pro Pass is a consumable, not a subscription, and must not be created as one.** The vault
sells it as a one-month, one-time $9 purchase. In StoreKit that is a *consumable*: it can be bought
again once it lapses, which a non-consumable cannot, and it does not belong in the subscription
group with Monthly and Annual. Getting this wrong is not a display bug, it is a wrong product in
App Store Connect that has to be replaced rather than edited. `ProProduct.kind` records it.

One limitation worth knowing: `GET /api/me` reports one *effective* plan, not which product paid
for it, so a paying reader cannot be shown which of the three they are on. The list marks only Free
as current, because guessing at somebody's own subscription is worse than saying nothing.

## The StoreKit seam, ready to wire (added 2026-09-04)

`Services/ProStore.swift` is where In-App Purchase will go. Nothing talks to StoreKit yet, and the
point is that every screen offering Pro already calls **through** it, so wiring is writing one
conforming type rather than reworking onboarding. `PlaceholderProStore` answers `.notConfigured`
and callers behave exactly as before. The file itself carries the step-by-step checklist; the parts
worth knowing away from the code:

- **Two products, not three.** `ProProduct` has `monthly` and `annual`. The trial is an
  **introductory offer on the monthly product**, which is why `Plan` on the plan beat has three
  cases and `ProProduct` has two. Both subscriptions must sit in **one subscription group**, or a
  reader cannot switch between them without double-paying.
- **A Restore Purchases control has to be added when wiring.** App Review requires a restore path
  for auto-renewable subscriptions. `restore()` is on the protocol so the call site is obvious, but
  there is deliberately no dead button for it today.
- Whatever trial length is configured in App Store Connect has to match the plan beat's copy, and
  it still needs adding to the vault, which does not mention a trial at all.

**Two bugs were fixed in the same pass, both real today and both worse once money is involved:**

- **An existing subscriber was pitched a trial for what they already pay for.** All three answers to
  the account ask now leave through `advanceFromAccountAsk()`, which skips the plan beat when
  `ProEntitlement.isPaid()` says the account is on `pro` or `business`. That reads `GET /api/me`,
  the same endpoint `SubscriptionView` and the web's `usePlan` use, so it works today with no
  StoreKit: the plan lives server side and a subscriber signing in on the phone is known at once.
  A failed request answers false and shows the offer, because being pitched something you own is a
  smaller harm than never being able to buy it.
- **An already signed-in reader got an incoherent account ask.** The advance was driven by
  `onChange(of: clerk.user?.id)`, which only fires when the id *changes*, so a session restored at
  launch left the beat asking an authenticated reader to create an account, with both buttons
  opening `AuthView` for a user already in it. It now checks `clerk.user` when the beat renders and
  offers a single Continue, with the supporting copy switched to match. This was hit constantly in
  testing, because `-show-onboarding` on a signed-in device reproduces it every launch.

### The plan screen is design only (added 2026-09-03)

A fifth beat, `plan`, sits after the account ask: a flat BLURPLE field offering a 14-day free trial
or a monthly subscription, with "Not now". **Nothing on it is wired to StoreKit**, at Chris's
request, and three things must happen before it can ship in a submitted build:

1. **Guideline 3.1.1.** Digital goods must go through In-App Purchase. These buttons currently just
   end onboarding, and a purchase screen that does not purchase is itself a rejection risk. Wire it
   or hide it before submission.
2. **The 14-day trial is not in the vault.** `Claude Skill.md` section 3 lists Pro Monthly $5,
   Pro Annual $39 and the $9 Pro Pass, with no trial. A trial is a StoreKit introductory offer
   configured in App Store Connect, and if it stays it is a pricing decision the vault needs.
   The $5 monthly figure on screen does come from the vault.
3. Pro Annual is deliberately not offered here. Two options was the ask; adding a third is a
   conversion decision, not a layout one.

It keeps a "Not now" exit for the same reason the account ask does.

### The launch screen carries the brand moment, not a slide (decided 2026-09-03)

`UILaunchScreen` was `{}`, an empty dict, which is why launch showed a blank white frame and why
"a blank white frame is launch lag, not a crash" is a note further up this file. It is now CORAL
with Lauma's head centred, which is the design Chris mocked up.

That mock was originally proposed as onboarding's *first screen*, and it read as incomplete for a
structural reason worth keeping: a wordless logo screen is an interstitial, not a screen. Asking it
to be a content screen gives it nothing to say and costs a tap. As a launch screen it is free, it
is exactly where a wordless brand moment belongs, and it replaces a white flash. The introduction
Chris wanted then became onboarding's first *real* screen, with words.

Two constraints that shaped it:

- **A launch screen cannot run Swift**, so it cannot read `BrandColor`. The coral therefore lives
  in the `LaunchBackground` colour asset, and that is the single sanctioned copy of a brand value
  outside `DesignSystem/`. If the brand coral ever moves, change it in both places.
- **`UILaunchScreen` centres exactly one image**, so the wordmark cannot sit at the bottom the way
  the mock had it. Hence the head alone here, and `ColorSenseWordmark` on the `hello` beat instead.

One open question: the teal is `BrandColor.teal` (#4ECDC4, the vault's value). Chris supplied a
swatch image that read slightly softer, but a pasted image cannot be sampled, and hardcoding a
second teal outside `DesignSystem/` would break this file's own rule. If a different teal is
wanted, add it to `BrandColor` with its hex rather than inlining it.

**`UILaunchScreen` now sets a colour and no image, and that is a retreat, not a preference.**
`UIImageName` worked with a portrait full-body sprite (once its 1x/2x/3x were exact multiples: a 3x
one pixel wide of 3x the 1x makes the image silently skip, with no build warning and no runtime
error) but rendered nothing at all for the landscape head, across a fresh install, a simulator
reboot, exact multiples and a renamed asset. Rather than keep paying for that, the launch screen is
CORAL only and the app's `splash` beat paints the same coral with the head on it. Same colour,
so the handover has no seam, and a launch screen that is only a colour cannot get it wrong.

**The `UILaunchScreen` key is required even when it carries only a colour.** Deleting the key
outright (which happened here while removing `UIImageName`) leaves the app with no launch screen,
and iOS silently falls back to compatibility mode: every screen renders letterboxed inside black
bars instead of full bleed. It builds, it runs, and nothing warns. If the app ever stops filling
the screen, check this key first.

**Do not try to crop a head out of a full-body pose.** It was tried: the cut was made at the
measured narrowest silhouette row (52% of height, the neck), the least-bad horizontal cut available,
and it still read as a chopped chin on device. Her head and body are a single shape with no neck
between them, so the jaw curve continues past every candidate cut line and any horizontal crop
flattens it. `LaumaHead` is instead matted out of the **dedicated head render** Chris supplied,
which has a complete jaw and needed only a background flood fill.

**The full-body emotion set landed 2026-09-03** in `NextCloud/ColorSense` (delighted, curious,
surprised, unsure, sad) and is cut and installed. `LaumaCurious` is now full-body, replacing the
chest-framed bust of the same name; the remaining bust, `LaumaReassuring`, was deleted because its
framing is off-system. `LaumaSurprised`, `LaumaUnsure` and `LaumaSad` ship unused, for error and
empty states.

**The shadow is a ground shadow, not a drop shadow** (changed 2026-09-03). `.shadow()` on the
sprite traces its outline, which is exactly what makes a flat character read as a sticker laid on
the surface: a second Lauma, in grey, peeking out from behind the first. Chris called it out as
"sticker like". A standing figure lit from the front does not do that; it puts a pool on the floor
beneath itself. So `LaumaStage.groundShadow` is an ellipse at her feet with a radial gradient
(dense centre, vanishing rim) drawn with `.blendMode(.multiply)`. Multiply matters: it *darkens the
band it lands on* rather than laying neutral grey over it, which is the difference between a shadow
on CORAL looking like deeper coral and looking like dirt. It correctly disappears on a near-black
band such as the Bold palette's first swatch, because there is nothing left to darken.

**The blink is real animation frames, not synthesis** (added 2026-09-03). Chris supplied
`Downloads/2026-09-03 13:43:33.MOV`, a 24fps generated animation of her head blinking. The video
itself is not shippable: a "KlingAI 3.0" watermark is burned into the top-right and bottom-right,
and a 4.7MB H.264 with an audio track is a silly way to play 0.4s of eyelid. What made it usable is
that the head's bounding box is **pixel-identical across all 35 frames** (195,660,780,1176) and
sits clear of both watermarks, so cropping to the head drops the watermarks and the frames swap
with no jitter. Ten frames were kept (open, three closing, shut, four opening, open), matted off
the video's coral, which is *not* `BrandColor.coral`, so they must be composited rather than laid
on a matching field. `LaumaBlink` plays them on the `splash` beat.

Note the animation's Lauma drifts slightly from the still art (a larger, paler muzzle), so the
splash head and the `hello` full body are not quite the same rendition. Only worth fixing if it
reads as wrong on device.

**Three beats now use animation rather than a drawn pose** (added 2026-09-04), all through
`LaumaClip`:

- `hello` uses `.wave`, from `Downloads/2026-09-04 00:14:10.MP4` (784x1176, 24fps, 3.042s).
- `naming` uses `.naming`, from `Downloads/2026-09-04 01:09:50.MP4` (960x960, same length).
- `plan` uses `.cheer`, from `Downloads/2026-09-04 01:00:33.MP4` (960x960, same length).

Each is cut to 30 frames at roughly 10fps, in `LaumaWave00`...`29`, `LaumaName00`...`29` and
`LaumaCheer00`...`29`. Same two problems as the blink clip and the same answers: a burned-in "KlingAI 3.0" watermark, painted
back to white before anything reads the pixels, and a solid white plate rather than alpha, cut by
flood-filling inward from the border.

**Find the watermark as the part of the picture that never changes, not by position.** It is burned
in, so it is in every frame at the same place in the same colour, while Lauma moves. The first
extractor instead took "the bottom-right corner of the frame where she is smallest", which is fine
for a clip where she recedes and wrong for one where she does not: on `.cheer` it stretched the box
to x=480-941 and painted her back leg white. The change-based detector puts it at x=764-941, clear
of her. If a third clip is ever cut, this is the part to keep.

Three things about these clips differ from every still pose and are load-bearing:

- **All 30 frames share one crop box.** The still poses are each trimmed to their own alpha bounds,
  which is what lets `LaumaStage` stand them on a band seam. Doing that here would cancel out any
  movement toward or away from the camera, which in `.wave` is the whole animation: she is full
  size for the first third, recedes to about a fifth of that, and returns. `.cheer` stays at one
  distance throughout, which is why it suits a screen where she is a reaction rather than the
  subject.
- **The ground shadow is driven by a measured table**, `Clip.stand`, holding each frame's
  silhouette centre, width and bottom as fractions of the frame. A fixed ellipse would sit at full
  size under a Lauma who has receded, which is exactly the detached-sticker look the shadow exists
  to prevent. The numbers come out of the extractor, not out of a guess.
- It is clock-driven like `LaumaBlink`, for the reason recorded there. Note the **Reduce Motion
  split is deliberate**: `LaumaClip` holds frame 0 under Reduce Motion, because these clips move
  her through space, which is what the setting is for. `LaumaBlink` does not, because an eyelid
  moves nothing. Getting this wrong once already cost real time: with Reduce Motion left on after
  the accessibility sweep, the blink never played on device and the animated wave rendered as a
  still that looked like the old pose, which read as three separate bugs.

**The recession is worth a second opinion.** She shrinks to a distant figure for roughly a third of
the loop, under a speech bubble introducing her, which can read as her walking away rather than
waving hello. It ships whole because that is the clip that was asked for; trimming to the full-size
frames (0 to 8 and 25 to 29) is a one-line change to `frameCount` and the table if it reads wrong.

**Bundle size is now the thing to watch.** The three clips add about 13.6MB (`.wave` 4.6MB at
900px tall, `.naming` 4.9MB at 620px, `.cheer` 4.1MB at 520px), taking the asset catalog to roughly
20MB, and the whole of the rest of the app is small next to it. Each clip costs about 4.5MB, so a
fourth is another 4.5MB and the trend matters more than any single one.

If it needs trimming, cut the frame **height** rather than the frame count: 30 frames over 3s is
already only about 10fps and dropping lower will stutter, whereas each clip is currently sized for
its 3x display height with no headroom to spare but no waste either. The real lever, if it ever
comes to it, is that these are lossless PNGs of flat cartoon art with soft edges; a shared sprite
sheet or a palette-reduced export would cut this substantially without touching the animation.
None of that is worth doing until an actual size limit is in view.

**The blink exists only for the head**, because that is the only pose the animation covers. Two
earlier attempts to synthesise one over the still art were built and rejected:

1. Fur-coloured lids drawn over the measured eye boxes. The eye positions were found properly (the
   sclera is the only pure-white region inside the figure; the cream muzzle is 247,229,201, a
   46-wide channel range) but a flat fill cannot match the art's paper texture, so the lids read as
   two stamps on her face. Also worth knowing for any future overlay: **apply the frame before the
   overlay**, or the eyelids' `GeometryReader` measures the unconstrained image and they land in
   the middle of her forehead.
2. Lids baked into a small patch by painting the eye out with neighbouring pixels. The fur sampling
   walked into the cream ear and left ghost outlines where the sclera had been.

A convincing blink needs **closed-eye art per pose**, which is one more generation pass on the kit.
Ask for that rather than attempting a third synthesis.

### `.background()` bleeds into the safe area by default (fixed 2026-09-04)

`View.background(_:ignoresSafeAreaEdges:)` defaults those edges to **`.all`**. That is exactly right
for the full-bleed bands, which is presumably why nobody looked at it, and wrong for any control
sitting near a screen edge.

The onboarding primary button was `.background(primaryFill)`. On the signed-in `keep` beat, where
Continue is the only control and therefore sits next to the bottom safe area, its fill painted
straight through that inset to the edge of the screen: a 52pt button rendered as an 88pt block
running off the bottom. With three controls the primary sits far enough up that nothing showed,
which is why it appeared the moment the signed-in single-button path was added.

**The frame was correct the entire time. Only the paint was wrong**, and that is what made this
expensive: a minimum height, `.fixedSize(vertical:)` on the control, `.fixedSize` on the band, and
finally a definite `@ScaledMetric` height were all tried and all measured identical, because none of
them was ever the problem. The thing that identified it was setting the height to a deliberately
absurd value and seeing the block *not* change. If a SwiftUI view renders larger than its frame and
changing the frame does nothing, look at what is painting, not at what is sizing.

Fixed with `.background(primaryFill, ignoresSafeAreaEdges: [])`. Any future control with a
background near an edge needs the same, and the bands must keep the default.

Two measurement lessons from the same session, both of which produced confidently wrong readings
before being caught:

- **`sips` writes 32-bit BGRA top-down BMPs**, not the 24-bit bottom-up assumed by the recipe in
  "Measuring UI alignment". Read `biBitCount` at offset 28 and treat a negative `biHeight` at offset
  22 as top-down, or every sample lands somewhere else in the image.
- **Uninstalling from the simulator wipes the persisted palette**, so a "clean reinstall" also
  changes every band colour and any detector keyed to a colour silently stops matching.

### The account ask is a soft gate (decided 2026-09-03)

iOS asks every reader to sign in or create a free account at the end of onboarding, and **the "no
signup required" line is gone from the app**. That promise is now web-only. This reverses the
vault's own positioning, and `Claude Skill.md` **has been reconciled** (2026-09-03) in four places:
section 2's product line and Positioning paragraph, section 3's free-tier row, and the iOS
paragraph in section 22. The rule for copy is now: "no signup required" is a claim about the *web
app*, never a blanket ColorSense claim. "Free, unlimited, no paywall" is still true everywhere.

It is a **soft** gate: create an account, sign in, or "Maybe later". Two App Review rules drove
that, and both still need watching:

- **Guideline 5.1.1(v)** does not allow requiring registration for features that do not need an
  account. The Extractor and WCAG checker run entirely on device, so a hard wall in front of them
  is a plausible rejection. The "Maybe later" exit is what keeps this safe.
- **Guideline 4.8** requires Sign in with Apple wherever a third-party sign-in is offered. Clerk's
  `AuthView` currently shows Google and no Apple button, confirmed by screenshot. **Apple must be
  provisioned before this ships**, or the account screen is a rejection on its own. See "Auth"
  below for what is still outstanding there.

`AuthView(mode: .signUp)` and `AuthView(mode: .signIn)` are distinct flows, which is why the two
buttons are honest rather than decorative.

### Voice

Copy follows the vault's section 9 rules, and the first attempt did not. Two that bite:

- **No em dashes or en dashes in anything a user can read.** Section 9 makes this a mandatory
  output gate and section 21 repeats it. The first onboarding draft was full of them. Scan the
  literal characters before shipping copy; reading for them is how a dozen got missed once before.
- **"Specific and grounded. Not generic observations."** This is the written form of the complaint
  above. "Which of these feels like you?" is abstract; naming CORAL and Bittersweet is not. Color
  words go in ALL CAPS.

### Where Lauma appears outside onboarding (decided 2026-09-04)

**The clips are the first run. Everywhere else she is a still.** The drawn poses are already in the
bundle, so a notice costs no bundle at all, while each animated clip is about 4.5MB. That rule is
what keeps her usable everywhere without the asset catalog growing.

`DesignSystem/LaumaNotice.swift` is the one way an empty, failed or refused screen speaks: pose,
title, message, optional actions. It replaced four hand-rolled copies of the same shape (a coral SF
Symbol over two lines) that had drifted apart in spacing. `LaumaStage` moved from `Features/
Onboarding/` to `DesignSystem/` in the same pass, because the mascot is brand rather than an
onboarding detail.

In use, with the pose chosen to mean something:

- Saved palettes and saved colors, empty: **CURIOUS**.
- Both of those failing to load: **SAD**, with the existing retryable-only "Try again".
- Photo permission refused: **UNSURE**, not SAD. A refused permission is a shrug, not a failure,
  and three routes forward are offered, so nobody is stuck.
- Library search with no matches: **UNSURE**.

**Where she deliberately does not go**, and this is the half that keeps her worth something:

- **Not on the palette screen.** It is the product, and a mascot standing on somebody's colours is
  the sticker problem in another costume.
- **Not on spinners.** There are a dozen `ProgressView`s in this app and nearly all resolve in well
  under a second; a mascot that flashes for 400ms is noise. A wait has to be long enough to be
  *felt*, roughly over 1.5s, before she improves it.
- **Not on tool sheets, detail views or settings.** Utility surfaces, where she would be decoration.

Adding her somewhere new is a judgement about whether there is a *moment* there, not a free win.

### The mascot kit

`ColorSense Lauma Mascot` (18 PNGs, delivered 2026-09-03) supersedes the single waving prototype.
It has a four-view turnaround, four full-body poses the sheets name WELCOME, GUIDE, WALK and
CELEBRATE, and six expression busts (HAPPY, CURIOUS, THINKING, UNSURE, DISAPPOINTED, REASSURING).
Eight are in the catalog as `Lauma*` imagesets; `LaumaPrototype` was deleted.

Two things to know before touching the art again:

- **The source files have no alpha.** All 18 are RGB on white, and her eye whites sample at the
  same 254 to 255 as the paper, so a global white key punches holes straight through her eyes. The
  cutouts were made by **flood-filling inward from the border** (background is connected to the
  frame edge, eye whites are enclosed), then one box-blur pass for a ~1px soft edge, then a trim to
  the alpha bounding box. That trim matters: the bottom of each sprite is the bottom of her hooves,
  which is what lets `LaumaStage` stand her exactly on a band seam. If new art arrives, prefer an
  export with real transparency over repeating this.
- **`Image(decorative:)`, always.** A plain `Image(_:)` adopts its asset name as an accessibility
  label, which is how the literal string "LaumaPrototype" ended up in the accessibility tree.

`LaumaStage` now does very little, because the drawn poses carry the expression: a slow breath and
a cross-fade between poses, both suppressed under Reduce Motion.

Swept at accessibility-extra-large, in light and dark, and with Reduce Motion on.

## Running the app

`./Scripts/run-sim.sh` builds, installs, launches, and writes `.build/sim-screenshot.png`. It
boots iPhone 17 if no simulator is already running. This is the way to actually *see* a change —
use it rather than reasoning about whether the layout is right.

Launch with `-sample-palette` (`xcrun simctl launch booted online.colorsense.ios -sample-palette`)
to open on `ExtractedPalette.sample` regardless of what is stored. Those five swatches are the
ones in the web app's mobile palette view, so a screenshot is a direct side-by-side check.

To test first-launch behaviour, `xcrun simctl uninstall booted online.colorsense.ios` first —
otherwise the persisted palette is restored and you'll never see `.brandDefault`.

First paint lags launch by several seconds (Clerk's placeholder-key requests run during
startup). Screenshotting sooner captures a blank white frame that looks like a crash but isn't;
`run-sim.sh` already waits.

Expect a stream of `[Clerk] ❌ host_invalid` errors in the log on every launch. That is the
placeholder publishable key failing against a fake host, is documented under "Status" below,
and is not a crash — don't chase it.

## Ported from the web app — keep in step

The web source is **not** in this repo. It lives at `~/Documents/Codex/ColorSense/ColorSense`
(a second, older copy is in iCloud). These files are line-for-line ports; if you change the math
or copy on one side, change it on the other in the same pass, or the two products start
disagreeing about the same hex.

| iOS | Web source | What must stay identical |
|---|---|---|
| `Services/ColorNameService.swift` + `Resources/ColorNames.json` | `lib/colorNames.ts` | 1,566 ntc names; nearest match by squared RGB distance |
| `Services/ColorMath.swift` | `lib/labColor.ts`, `lib/colorHarmony.ts` | HSL/CMYK/LAB(D65)/LCH formulas, rounding, and conversion row order |
| `Services/ColorHarmony.swift` | `harmoniesFor()` in labColor.ts | Four harmonies, ±30/180/150/210/120/240 offsets, the near-grey guard (s < 0.05 → s 0.6, l 0.55) |
| `Services/ColorInsights.swift` | `colorInsights()` in labColor.ts | Psychology/Meaning/Applications copy **verbatim**, hue boundaries, the s < 0.12 neutral cutoff |
| `ContrastCalculator.rating(for:)` | `rateContrast()` in labColor.ts | The 5-point labels and their 7 / 4.5 / 3 / 2 thresholds |
| `Features/Extractor/PaletteGenerator.swift` | `relatedPalette()` in labColor.ts | Scheme tables, jitter magnitudes, clamps, `widen = iteration >= 10` |
| `Features/Palette/ColorDetailView.swift` | `components/lab/ColorDetailCard.tsx` | Section order and labels |
| `Services/PaletteHealth.swift` | `lib/paletteHealth.ts` | Five dimensions, their thresholds and weights, the A–F bands, and the detail/tip copy verbatim |
| `Services/PaletteHealthReport.swift` | `lib/paletteHealthReport.ts` | Role assignment, contrast-row selection and ordering, and the summary wording |
| `ContrastCalculator.suggestFix` | `suggestFix()` in `lib/wcagContrast.ts` | 0.01 lightness steps, hue and saturation held, direction away from the anchor, 8-bit quantised before each measurement |
| `Services/ColorBlindness.swift` | `lib/colorBlind.ts` | Machado 2009 matrices at severity 1.0, applied in linear sRGB; ΔE < 14 confusable threshold |
| `Services/SvgRecolor.swift` | `SvgRecolorPanel.tsx` | `normalizeColor`, `extractColorsFromSvg`, `colorVariants`, `recolorSvg`: which properties are read, the four skipped non-colours, shorthand expansion, and the `found[i] -> palette[i % n]` mapping |
| `Services/SavedPaletteService.swift` | `routes/saved-palettes.ts`, `lib/savedPalettes.ts` | `POST /api/saved-palettes`, `{name, colors}`, uppercase `#RRGGBB`, Bearer token, ≤20 colors |

`ColorMathTests.swift` pins the whole chain to values read off the web's own detail card for
#666770 — if a port drifts, those fail. Extend that fixture rather than trusting a visual check.

Deliberate divergences:
- The web's "Generate Harmonies · AI · Pro" button is **not** on iOS. There is no StoreKit here,
  and App Store review rejects digital-goods upsells that route around IAP. Revisit when Pro
  actually ships on iOS.
- Auto-remap and the Contrast tool's "Fix it" are **both live now**, both Pro-gated, and both are
  the same ported algorithm — `ContrastCalculator.suggestFix`, from `suggestFix()` in
  `lib/wcagContrast.ts`. They differ only in which colour they move: "Fix it" adjusts the *text*,
  since a background is usually the fixed thing in a real design, while the report's remap adjusts
  the *surface*, because the report already chose the text as the one a designer would use.
- **Neither fix applies itself.** Tapping proposes: `ContrastFixSheet` shows the failing pairing,
  the measured before and after, and the new hex, and nothing changes until the reader presses
  Apply. Both surfaces route through it, and the health report passes *every* failing pairing so
  the choice of which to correct stays with the reader. Changing a colour somebody chose — often a
  brand colour — without asking would be the app overruling its user on the one thing the product
  is about.
- **Both buttons are always present**, pinned to the bottom of their screen: coral when there is
  something to fix, grey when there is not. Inline, they only appeared when something was already
  broken, so a palette that scores well — which the brand default does — never revealed the
  feature existed. Being locked deliberately does *not* borrow the grey, or a free reader mistakes
  "Pro" for "all fine".
- **A free tap opens the same sheet**, which names Pro and shows the fix in full including the new
  hex. There is no upgrade button and no link, because there is nothing legitimate to link to: the
  app has no StoreKit, and guideline 3.1.1 forbids sending people to an outside purchase — the
  same rule that removed "Pro is available at colorsense.online". **Until StoreKit ships there is
  no in-app route to Pro at all**, and adding one is the piece of work that unblocks it.
- The health report's fix copy still points at the swatch editor rather than at the remap button,
  since the copy is shown to free readers too and would otherwise describe a control they cannot
  press.
- Tapping a harmony swatch copies its hex. On the web it *adds* the color to the palette;
  iOS has no add-color affordance yet.

Also note `isDark()` in labColor.ts picks label color by perceived luminance
(0.299/0.587/0.114), while iOS uses `ContrastCalculator.prefersLightText` (WCAG ratio), because
CLAUDE.md requires contrast decisions to route through `ContrastCalculator`. They agree on every
color tested so far, but they *can* disagree on mid-tones. Deliberate, not an oversight.

## SVG Recolor (added 2026-09-04)

The first of the remaining web tools to come across. `Services/SvgRecolor.swift` is the port and is
covered by `SvgRecolorTests`; the screen around it is `Features/SvgRecolor/`.

**It is Pro, matching the web.** The gate follows the `ContrastFixSheet` precedent: it names Pro and
offers no way to buy it, because there is no In-App Purchase yet and guideline 3.1.1 forbids
pointing at an outside one. Unlike the contrast fix, the locked state cannot show its value in full,
because there is nothing to show before a file is opened, so it describes the tool instead. `isPro`
comes from the same `GET /api/me` read the rest of the app uses.

**iOS cannot draw SVG**, which is the one genuinely unavoidable decision here. There is no
`UIImage(svg:)`, `Image` does not read it, and the alternatives were a third-party renderer or
writing a rasteriser. `SvgPreview` is therefore a `WKWebView`, and that does **not** reopen the
"fresh native SwiftUI, not a WebView wrapper" decision: that ruled out proxying the app's own
screens to the website, while this draws a local string in a format the platform cannot display.

Three things keep hosting an untrusted document safe, and all three must stay:

- **JavaScript is off** (`allowsContentJavaScript = false`). This is the actual defence, not the
  sanitiser.
- **Nothing loads from the network.** The SVG is passed as a string with `baseURL: nil`, and the
  navigation delegate refuses every navigation except the initial `about:` load.
- **`SvgRecolor.sanitized` strips `<script>`, `<foreignObject>`, `on*` handlers and
  `javascript:` URLs.** DOMPurify has no Swift equivalent, so this is the same intent rather than
  the same implementation. It matters most on **export**, where the file leaves for applications
  this app does not control, rather than in the preview where script cannot run anyway.

**Polish pass, 2026-09-04.** Four things worth not regressing:

- **The error alert lives on the whole screen, not on the editor.** It was attached inside
  `editor`, which is the one state that cannot be showing when a load fails: a failure means there
  is no source, so the chooser is up. The message was unreachable in exactly the case it existed
  for. It also uses a real binding rather than `.constant`, so any dismissal clears it.
- **A file with no colours says so.** Painting entirely with `currentColor` or with gradients is
  legitimate and not an error, but it leaves nothing to remap, and an empty list explains nothing.
- **The checkerboard follows the appearance.** Hardcoded light greys glowed in dark mode, reading
  as a rendering fault rather than as "nothing here".
- **The preview is one accessibility element with a label.** It is a `WKWebView`, so VoiceOver
  would otherwise walk its DOM, which is worse than useless; the rows below carry the information.

Swept in dark mode and at accessibility-extra-large.

**The preview takes the artwork's shape** (changed 2026-09-04). It was a flat 240pt box whatever
the file was, so a wide banner sat small between two bands of checkerboard and a tall logo sat
narrow between two more. `SvgRecolor.aspectRatio(of:)` reads the `viewBox` (preferring it over
`width`/`height`, since it is the coordinate system the drawing is authored in and survives files
that give no size at all) and the canvas matches it, clamped between 150pt and 330pt so a long
banner cannot collapse to a sliver and a tall crest cannot push every row off the screen.

**The palette in the picker is the live one**, which is the whole "one palette, many tools" point:
whatever the Extractor pulled out of a photo, or Generate produced, is what the SVG tool offers.
Nothing had to be built for that, and nothing should be: the tool takes `store.palette` like every
other tool does.

**The choosing lives in a sheet, not in the rows** (changed 2026-09-04). The first version put a
strip of palette swatches under every found colour, so a five-colour file repeated the same five
circles five times and it read as a wall of dots with no order to it. Now each colour is one compact
line, tappable, and `SvgColorPicker` does the choosing: the palette first, because it is the reason
the tool exists, then any colour, then a way back to the original.

**The arbitrary-colour control is the app's existing one.** `CustomColorEditor` was extracted from
`AddColorView`, which owned the only copy, and is now shared by both. Entering a colour therefore
works identically everywhere: same field, same filtering as you type, same message when the
clipboard holds something that is not a colour. A second implementation would have drifted, and
this one has behaviour worth keeping.

One deliberate divergence from the web panel remains:

- **Export goes to the share sheet**, not a download, because that is what "hand it to the device"
  means on iOS. Same distinction as "Save to my account" versus "Share as image".

## Color names (ported from the web app, 2026-09-02)

`Resources/ColorNames.json` is the same 1,566-entry Name That Color dataset the web app bundles
at `artifacts/color-palette/src/lib/colorNames.ts` (web source lives outside this repo, at
`~/Documents/Codex/ColorSense/ColorSense`). `ColorNameService` matches with the same rule the web
app uses: smallest squared Euclidean distance in 0...255 RGB.

Plain RGB distance is not perceptually ideal — Lab would name some colors better. It is used
anyway so a given hex gets the *same* name on iOS and the web. Don't switch the metric here
without changing the web app in the same pass.

No `.xcodeproj` is committed. This project is managed with
[XcodeGen](https://github.com/yonaskolb/XcodeGen) via `project.yml` — the project file is
generated, not hand-edited. Add new source files by creating them under `ColorSense/` (XcodeGen
picks up the whole folder) and re-running `xcodegen generate`; don't try to add files via Xcode's
"Add Files" first, since that edits the generated project, not the source of truth.

## First-time machine setup

Done as of 2026-09-02 on this Mac: Xcode 26.6 (full install) is present, Homebrew 6.0.21
is installed (`eval "$(/opt/homebrew/bin/brew shellenv)"` is in `~/.zprofile` — open a
fresh terminal or re-source it if `brew`/`xcodegen` aren't on PATH), xcodegen 2.46.0 is
installed, `Config/Secrets.xcconfig` exists (copied from the `.example`, still has the
**placeholder** key — swap in the real `CLERK_PUBLISHABLE_KEY` from the ColorSense Clerk
dashboard before auth will actually work), and `xcodegen generate` has produced a working
`ColorSense.xcodeproj` in this location.

If setting this up again on a different machine, repeat: install Xcode from the App Store,
install Homebrew, `brew install xcodegen`, copy the secrets file, `xcodegen generate`,
`open ColorSense.xcodeproj` — and do it on local disk, not inside a synced folder (see
"Location" above).

`Config/Secrets.xcconfig` (gitignored) now carries three values: `CLERK_PUBLISHABLE_KEY`
(production, `pk_live_…`, the same key colorsense.online serves), `DEVELOPMENT_TEAM` for device
signing, and optionally `API_BASE_URL` / `CLERK_PROXY_URL` to point at a local api-server.

## Fonts (done 2026-09-02)

`ColorSense/Resources/Fonts/` holds the four faces `project.yml` declares in `UIAppFonts` and
`BrandFont.swift` references: `BebasNeue-Regular`, `DMSans-Regular`, `DMSans-Medium`,
`DMSans-Bold`. Verified rendering on device and in the simulator.

Two things to get right if these are ever replaced:

- **DM Sans ships in many optical sizes.** Use the `static/` files with *no* size suffix
  (`DMSans-Regular.ttf`), not `DMSans_18pt-Regular.ttf` or the variable-font builds. The
  suffixed ones carry different PostScript names and `Font.custom` silently falls back to the
  system font rather than failing.
- **`Font.custom` matches on PostScript name, not filename.** Check the name inside the file
  before trusting it — a `.ttf` can be named anything. There is no tooling for this on the
  machine, but the TrueType `name` table (nameID 6) is parseable in a few lines of plain Python.

A missing or misnamed font never crashes; it silently renders as system font, which is exactly
why this went unnoticed for several sessions of screenshots.

Hex codes deliberately use `BrandFont.mono` (system monospaced) rather than a brand face —
there is no brand mono, and digits need to align down a stack of bands.

## Auth (Clerk) — verified API surface, 2026-09-02

Confirmed against Clerk's iOS docs (github.com/clerk/clerk-ios, clerk.com/docs/ios) at
time of writing. If Clerk ships a new major SDK version, re-check the quickstart before
trusting this:

- Packages: `ClerkKit` (core) + `ClerkKitUI` (prebuilt SwiftUI views), SPM from
  `https://github.com/clerk/clerk-ios`, `from: 1.2.0`.
- Configure once at launch: `Clerk.configure(publishableKey:)`.
- Inject into environment: `.environment(Clerk.shared)`; read with `@Environment(Clerk.self)`.
- `AuthView()` — prebuilt sign-in/sign-up flow, presented as a sheet in `AccountView`.
- `UserButton(signedOutContent:)` — profile button when signed in, custom sign-in trigger
  when signed out.
- Clerk SDK's own minimum deployment target is iOS 17, which is part of why this project's
  deployment target is 17.0.

### The Clerk tenant is Replit-managed (learned 2026-09-02)

There is no standalone ColorSense Clerk account. Replit provisions the instance and injects
`CLERK_SECRET_KEY` / `CLERK_PUBLISHABLE_KEY` / `VITE_CLERK_PUBLISHABLE_KEY`; Google sign-in was
enabled through Replit's workspace Auth pane, not a Clerk dashboard. Signing in to
dashboard.clerk.com with a personal email just creates a new, empty org — that is not the
ColorSense tenant. Dashboard access requires an active Replit Pro subscription.

**Never create a separate Clerk application or swap the publishable key.** That disconnects iOS
from the production user store, and every existing account with it.

Development and Production have **separate user stores**. iOS uses the production key, which is
the same one colorsense.online serves — so the two share accounts, which is the point.

### Sign-in goes through the web app's proxy, not the key's own host

`clerk.colorsense.online` — the host encoded in the publishable key — **does not complete a TLS
handshake**. TCP connects, then the server answers with a protocol-version alert. Reproduced from
iOS (`-9824`) and macOS/LibreSSL (`tlsv1 alert protocol version`), on two networks, Wi-Fi and
cellular. DNS is fine; it CNAMEs correctly through `frontend-api.clerk.services`. This reads as a
custom domain whose certificate was never provisioned.

The web app is unaffected because ClerkJS is configured with `proxyUrl`, routing through
`colorsense.online/api/__clerk` (`clerkProxyMiddleware()` in the api-server). iOS does the same
via `Clerk.Options(proxyUrl:)` — see `AppConfig.clerkProxyURL`.

Symptom if this ever regresses: `AuthView` renders its header and **no form fields at all**.
`AuthStartView` derives every field from `clerk.environment?.enabledFirstFactorAttributes`, so a
nil environment silently produces an empty sign-in screen rather than an error.

### OAuth redirect

Clerk's iOS SDK defaults its redirect to `{bundleIdentifier}://callback` — for us,
`online.colorsense.ios://callback`. Two halves, and both are required:

1. The app owns the scheme (`CFBundleURLTypes` in `project.yml`) — done.
2. The URL is allowlisted on the production Clerk instance — done through its Backend API.

Google sign-in now completes on a physical iPhone. Email-code sign-in also lands in the *same*
account, because Clerk matches users by email — verified by signing in with email on iOS and
finding palettes saved earlier from the web.

### Native Sign in with Apple

The Sign in with Apple entitlement lives in `Config/ColorSense.entitlements` and is attached by
`project.yml`. It is enabled for Release but deliberately omitted from
Debug while this project uses a Personal Team: Apple refuses to provision this capability for
Personal Teams, and enabling it for Debug would prevent every physical-device build. Once a paid
Apple Developer team is selected, enable the entitlement for Debug too so the native flow can be
tested before release. ClerkKitUI's existing `AuthView` automatically uses
`clerk.auth.signInWithApple()` and shows the Apple button when Apple appears in the Clerk
environment's enabled social providers. It does not use the browser OAuth redirect above.

The remaining account-side setup is to enable Sign in with Apple for the
`online.colorsense.ios` App ID, register the Team ID and bundle ID as a Clerk Native Application,
and enable Apple for sign-up and sign-in on the production Clerk instance. Do not add a custom
Apple button to work around missing provider configuration; it would only expose a flow the
backend is not ready to accept.

There is no public API to hide a single social provider from `AuthView`; providers come straight
from the environment. Hiding the Google button would mean replacing `AuthView` with a custom
email-only screen built on ClerkKit's lower-level API.

### The plan must be read *after* the session exists (fixed 2026-09-04)

`RootView.refreshPlan()` ran from a bare `.task`, which fires as the view appears, and at a cold
launch that is **before Clerk has restored the session**. `authorizedRequest` bails with
`.notSignedIn` before it makes any request, so the plan came back as a failure, `isPro` was set
false, and nothing retried it until the account sheet happened to open and close. **A paying reader
was locked out of every Pro feature on every cold launch.**

It went unnoticed for a while because the older Pro surfaces degrade quietly: the contrast fix and
the health remap still show their value and merely decline to apply it. SVG Recolor is gated
outright, so it was the first place the bug was visible, and it looked like an SVG bug rather than
what it is.

Two changes, and both matter:

- `.task(id: clerk.user?.id)`, so the read runs again the moment a session arrives and again when
  it goes away. This is the same lesson as `LaumaBlink` and the splash timer, in a different
  costume: **do not read state at appear time that something else is still loading.**
- A failed request no longer revokes Pro. Signed out is a definite answer and sets false; a failed
  request while signed in is not an answer at all, and used to drop a paying reader to free on any
  network blip. It now leaves the last known value alone.

The other `.task { await load() }` calls live inside sheets a reader opens well after launch, and
they surface a retryable error rather than degrading silently, so they were left alone.

### API calls need an explicit bearer token

The web relies on Clerk session cookies. Mobile does not — every call to the ColorSense API must
attach `Authorization: Bearer <session token>` from `session.getToken()`. `SavedPaletteService`
does this in one shared helper; route new endpoints through it rather than repeating it.

## What NOT to do without asking

- Don't paywall the Extractor or WCAG Checker. The vault is explicit that these are free/
  unlimited/no-signup forever on the web app; the iOS versions inherit that rule.
- Don't add the other 5 web tools (Brand Kit Creator, Palette Health Score, Website
  Analyzer, Scheme Generator, Color Picker from Image) as `Tool` cases without asking —
  that reopens the MVP scope decision above. `ToolsSheet` makes adding one mechanically
  trivial, which is exactly why the restraint has to be deliberate.
- Don't reintroduce a tab bar or a separate upload/landing screen. The app opens on the
  user's palette by design — see "One palette, many tools" above.
- Don't invent or hand-calculate WCAG contrast ratios in code comments, sample data, or
  docs — always route through `ContrastCalculator`, same rule the web app's content follows.
- Don't hardcode brand hex values or font names outside `DesignSystem/` — extend
  `BrandColor` / `BrandFont` instead, so there's one place that matches the vault.
