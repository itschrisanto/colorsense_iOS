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
  at all. This matches the "free, unlimited, no signup" positioning from the vault. The only
  networking is Clerk auth and `SavedPaletteService` (saving a palette to the user's account),
  both of which are opt-in and never block a tool.
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
  DesignSystem/      BrandColor.swift, BrandFont.swift — brand kit as Swift, not hardcoded per-view
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
- Sign-in and account-saved palettes still will not work on device: `CLERK_PUBLISHABLE_KEY` is
  still the placeholder.

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
| `Services/SavedPaletteService.swift` | `routes/saved-palettes.ts`, `lib/savedPalettes.ts` | `POST /api/saved-palettes`, `{name, colors}`, uppercase `#RRGGBB`, Bearer token, ≤20 colors |

`ColorMathTests.swift` pins the whole chain to values read off the web's own detail card for
#666770 — if a port drifts, those fail. Extend that fixture rather than trusting a visual check.

Two deliberate divergences:
- The web's "Generate Harmonies · AI · Pro" button is **not** on iOS. There is no StoreKit here,
  and App Store review rejects digital-goods upsells that route around IAP. Revisit when Pro
  actually ships on iOS.
- Tapping a harmony swatch copies its hex. On the web it *adds* the color to the palette;
  iOS has no add-color affordance yet.

Also note `isDark()` in labColor.ts picks label color by perceived luminance
(0.299/0.587/0.114), while iOS uses `ContrastCalculator.prefersLightText` (WCAG ratio), because
CLAUDE.md requires contrast decisions to route through `ContrastCalculator`. They agree on every
color tested so far, but they *can* disagree on mid-tones. Deliberate, not an oversight.

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

Still outstanding: confirm Swift Package resolution (Clerk SDK) completes cleanly here,
then do a real `xcodebuild` and run in a simulator. If setting this up again on a
different machine, repeat: install Xcode from the App Store, install Homebrew, `brew
install xcodegen`, copy the secrets file, `xcodegen generate`, `open ColorSense.xcodeproj`
— and do it on local disk, not inside a synced folder (see "Location" above).

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
