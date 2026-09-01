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

Not yet done: the real `CLERK_PUBLISHABLE_KEY` has never been set (still the local
placeholder in `Config/Secrets.xcconfig`), so sign-in itself is unverified. Bebas
Neue/DM Sans font files are still not in the repo (see "Fonts" below), so the simulator
screenshot shows system-font fallback, not the real brand type.

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
- **Build approach: fresh native SwiftUI**, not a WebView wrapper. Color extraction and
  WCAG math are reimplemented natively in Swift (see below), not proxied to the web app.
- **Backend: offline-first / on-device.** The extractor and WCAG checker do no networking
  at all. The only networking in the app is Clerk auth. This matches the "free, unlimited,
  no signup" positioning from the vault.
- **Auth: Clerk, wired from day one**, tied to the same Free / Pro Monthly ($5/mo) /
  Pro Annual ($39/yr) / Pro Pass ($9 one-time) plans as the web app, even though v1's
  own tools don't gate on it. This is forward-positioning for when Pro features
  (e.g. Brand Kit Creator, AI brand analysis) land on iOS.
- **Design: no mockups exist.** Screens are designed directly from the brand kit
  (colors/fonts below) using standard iOS/HIG patterns, not translated pixel-for-pixel
  from the web app.
- **Minimum iOS version: 17.0.** Not asked explicitly — chosen because the Clerk iOS SDK
  itself requires iOS 17+, so there was no lower option once Clerk was in scope.

## Architecture

```
ColorSense/
  App/              ColorSenseApp.swift (entry point, Clerk.configure), AppConfig.swift
  DesignSystem/      BrandColor.swift, BrandFont.swift — brand kit as Swift, not hardcoded per-view
  Models/            PaletteColor, ExtractedPalette
  Features/
    Extractor/       PhotosPicker -> ColorExtractionService (on-device k-means) -> palette grid
    WCAGChecker/      Two ColorPickers -> ContrastCalculator (WCAG 2.x luminance formula) -> AA/AAA badges
    Auth/             AccountView wraps Clerk's AuthView/UserButton
    Home/             RootTabView (Extractor / WCAG / Account tabs)
  Resources/
    Assets.xcassets/  AppIcon (needs a real 1024x1024 icon — placeholder slot only), AccentColor (set to Coral)
    Fonts/            EMPTY — see "Fonts" below, this is a manual step
ColorSenseTests/
  ContrastCalculatorTests.swift   Verifies the WCAG math against known values (black/white = 21:1, etc.)
```

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

Still outstanding: confirm Swift Package resolution (Clerk SDK) completes cleanly here,
then do a real `xcodebuild` and run in a simulator. If setting this up again on a
different machine, repeat: install Xcode from the App Store, install Homebrew, `brew
install xcodegen`, copy the secrets file, `xcodegen generate`, `open ColorSense.xcodeproj`
— and do it on local disk, not inside a synced folder (see "Location" above).

## Fonts (manual step, not yet done)

`ColorSense/Resources/Fonts/` is empty. `project.yml` already declares
`BebasNeue-Regular.ttf`, `DMSans-Regular.ttf`, `DMSans-Medium.ttf`, `DMSans-Bold.ttf` in
`UIAppFonts`, and `BrandFont.swift` already references them by PostScript name — but the
actual font files aren't in the repo. Download Bebas Neue and DM Sans (both on Google
Fonts) and drop the `.ttf` files into that folder. Until then, `Font.custom` calls will
silently fall back to the system font at runtime rather than crash.

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

## What NOT to do without asking

- Don't paywall the Extractor or WCAG Checker. The vault is explicit that these are free/
  unlimited/no-signup forever on the web app; the iOS versions inherit that rule.
- Don't add the other 5 web tools (Brand Kit Creator, Palette Health Score, Website
  Analyzer, Scheme Generator, Color Picker from Image) as new tabs/screens without asking —
  that reopens the MVP scope decision above.
- Don't invent or hand-calculate WCAG contrast ratios in code comments, sample data, or
  docs — always route through `ContrastCalculator`, same rule the web app's content follows.
- Don't hardcode brand hex values or font names outside `DesignSystem/` — extend
  `BrandColor` / `BrandFont` instead, so there's one place that matches the vault.
