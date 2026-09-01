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

## Status (as of 2026-09-02)

Scoping is done, initial scaffold is in place, zero screens have been run in a simulator yet.
Xcode is **not installed** on this machine (only Command Line Tools) — that's the next
blocker before anything here can build. See "First-time machine setup" below.

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

## First-time machine setup (do this before opening the project)

1. Install Xcode from the App Store (full Xcode, not just Command Line Tools — verified
   `xcodebuild` on this machine currently points at CLT only).
2. Install [Homebrew](https://brew.sh) if not already present (checked 2026-09-02: not installed).
3. `brew install xcodegen`
4. `cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig` and fill in the real
   `CLERK_PUBLISHABLE_KEY` from the ColorSense Clerk dashboard. This file is gitignored —
   never commit a real key.
5. `xcodegen generate`
6. `open ColorSense.xcodeproj`

None of this has been run yet, so the app has never actually been built or run in a
simulator. Treat "code compiles" as unverified until someone does step 1-6.

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
