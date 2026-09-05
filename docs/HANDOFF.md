# ColorSense iOS — handoff

Written 2026-09-05, at the point where every remaining task is gated on the Apple Developer
Program. Chris is enrolling. This is what you need to pick the project up.

## Read these first, in this order

1. **`CLAUDE.md`** in the repo root. It is long and it is load-bearing — decisions, reversals, and
   the reasons behind both. Do not skim it. Most "obvious improvements" you might reach for have
   already been tried and are recorded there with why they failed.
2. **`docs/APP-STORE-SUBMISSION.md`** — the submission checklist and the drafted App Store Connect
   metadata. This is the file to work from once the account exists.
3. **`docs/PRIVACY-AUDIT.md`** — an evidence-backed audit of what the shipping build actually does.
   It is the **baseline**, and section 8c of the submission doc says it must be re-run against the
   final archived Release build.
4. **The vault**, at
   `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Daily Notes/Knowledge Base/Claude Skill.md`.
   It owns pricing, brand, voice and positioning. Read it fresh rather than trusting a copy. If it
   and this repo disagree, the vault wins.

## Repo state

`main` at `b991510`, clean, fully pushed to `github.com:itschrisanto/colorsense_iOS`. **119 tests
pass.** Also on the remote: `diagnostics/photo-picker-repro`, a reproduction harness for the photo
picker — bring it back only if that screen misbehaves again.

No `.xcodeproj` is committed. This is XcodeGen: edit `project.yml`, add files under `ColorSense/`,
run `xcodegen generate`. Never hand-edit the generated project.

```bash
cd ~/Developer/ColorSense-iOS
eval "$(/opt/homebrew/bin/brew shellenv)"
xcodegen generate
./Scripts/run-sim.sh                      # build, install, launch, screenshot a simulator
xcodebuild -project ColorSense.xcodeproj -scheme ColorSense \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Device (an iPhone 17 Pro Max is paired, `xcrun devicectl list devices`):

```bash
xcodebuild -project ColorSense.xcodeproj -scheme ColorSense \
  -destination 'platform=iOS,id=<DEVICE_ID>' -derivedDataPath .build/device build
xcrun devicectl device install app --device <DEVICE_ID> \
  .build/device/Build/Products/Debug-iphoneos/ColorSense.app
xcrun devicectl device process launch --device <DEVICE_ID> --terminate-existing \
  online.colorsense.ios -- -show-onboarding
```

Useful launch flags that ship in the app: `-sample-palette`, `-show-onboarding`.

## Built, polished, signed off — do not touch

All of this has been through Chris on a physical iPhone and he has approved it. Do not restyle,
refactor or "improve" any of it without him asking.

- **Seven tools.** Extractor (an action on the dock, not a panel), Contrast, Palette Health, SVG
  Recolor, Visualizer, Schemes, Library.
- **The palette screen and the floating glass dock.** Icon-only, one coral focal point. The dock is
  the approved house bar; the tool strip was rebuilt to match it, not the other way round. Both come
  from `DesignSystem/DockChrome.swift` and are deliberately one object.
- **The tool workspace.** One `fullScreenCover`, panels stay mounted, one navigation bar with glass.
- **Onboarding**, all six beats, including the splash wordmark with its palette sweep, the four
  Lauma clips, the rebuilt account ask, and the plan beat.
- **Accounts, Library, About, Feedback, Share, export formats.**
- **Analytics and error tracking.** Narrow by design. `AnalyticsService` is the whole contract.

Two things in there are settled and often get re-litigated: the primary button is **white on coral**
even though the app's own checker rates that POOR, deliberately and at Chris's call; and the
Extractor stays on the dock rather than in the tool strip because it returns a palette and closes.

## What to do once the Developer Program is live

Work `docs/APP-STORE-SUBMISSION.md`. The order that matters:

1. **Register the App ID, provision Sign in with Apple**, enable the entitlement for Debug too, and
   register the Team ID and bundle ID as a Clerk Native Application. Until this is done **Release
   does not compile at all** — it fails signing. Everything else is downstream.
2. **Wire StoreKit.** Chris chose to keep the onboarding plan beat, so a purchase screen that cannot
   purchase is a live guideline 3.1.1 rejection and **the app cannot be submitted until this is
   done**. `Services/ProStore.swift` is the seam and carries the checklist. Two subscriptions in one
   group; the Pro Pass is a **consumable**, not a subscription; add a Restore Purchases control.
3. **Fix account deletion.** The app calls Clerk's `user.delete()` and nothing else, so the
   ColorSense Postgres row and every saved palette survive. This is a backend job — a verified Clerk
   `user.deleted` webhook — and the in-app copy currently claims otherwise. Details and the full
   deferred plan are in section 8c. **Do not change `/api/saved-palettes` or `/api/me` contracts.**
4. **Re-run the privacy audit** against the final archived build, then finalise the policy and the
   App Store questionnaire in the order section 8c gives.
5. **Settle the version numbers.** `MARKETING_VERSION` is still `0.1.0` and reads as a prototype.
   `CURRENT_PROJECT_VERSION` must increment on **every** upload — App Store Connect rejects a reused
   build number, and PostHog binds each dSYM to the release those numbers name. A symbol set already
   exists against `0.1.0+1`, so the collision is real, not theoretical.

## Open work that needs no account

- **The iPhone SE layout pass.** The highest-value one. Checking it found a submission blocker: the
  account ask laid out at 906.5pt on a 667pt screen and pushed "Maybe later" — the guideline
  5.1.1(v) exit — off the display. That is fixed, but the fix traded it for a hero that scrolls, so
  the last line of the paragraph can sit below the fold on any phone. Sizing the composition to fit
  is the finishing pass. **`mood` and `plan` have never been checked on an SE at all.**
- **Reconcile the vault** with what iOS actually ships: seven tools, Website Analyzer deferred,
  Brand Kit waiting on demand, Schemes landed, and the 7-day trial the vault still does not mention.
  This is not housekeeping — the onboarding Pro pitch promised brand kits and AI harmonies because
  it was written from the web's feature list, and the vault is where those lists come from.
- **App Store screenshots** at 6.9" (1320 x 2868), per section 7.

## Chris has feedback and new features to discuss

Take them, but know the ground rules before you agree to anything.

- **Adding a tool is a scope decision, not a code decision.** Adding a `Tool` case is mechanically
  trivial, which is exactly why the restraint is deliberate. Website Color Analyzer is **deferred**
  and Brand Kit Creator **waits for demand**. Do not build either without Chris explicitly asking.
- **Anything that exists on the web is a port, not an invention.** The web source is at
  `~/Documents/Codex/ColorSense/ColorSense`, and CLAUDE.md has a port table naming the file pairs
  and what must stay identical. Port the **lab panel**, not the standalone marketing page. When you
  port, pin it with tests whose expected values you produced by running the web's own arithmetic —
  that is how `ColorSchemeTests` was written, and it caught nothing only because the port was right.
- **The Extractor and WCAG checker are never paywalled.** Vault rule, both platforms, forever.
- **No purchase copy anywhere** until StoreKit ships. Guideline 3.1.1 covers prose, not just
  buttons, and it is why the About screen has no Support row and nothing names where to buy.
- **Copy rules:** American spelling in anything a user reads, no em dashes or en dashes, brand is
  always `ColorSense`. Colour decisions route through `ContrastCalculator`; brand values live in
  `DesignSystem/`.

## Traps that have cost real time here

- **Measure, do not eyeball.** Icon alignment, band heights and hit testing have all been got wrong
  by looking. CLAUDE.md has the screenshot-sampling recipe, including that `sips` writes 32-bit
  top-down BMPs.
- **The simulator lies about specific things.** The camera preview never runs, haptics do not exist,
  scrolling cannot be driven, and the onboarding blink played perfectly there while never once
  appearing on a phone. Device is the only proof for animation, camera and touch.
- **`devicectl --console` is not a witness.** It forwards stdout only and its session ends when the
  app is backgrounded, which it reports as "terminated with exit code 0". That looked exactly like a
  clean exit and sent a whole investigation down the wrong path. Log to a file in the app container
  and pull it with `devicectl device copy from --domain-type appDataContainer`.
- **`osascript` has no assistive access on this machine**, so simulator taps cannot be scripted.
  Temporary launch-argument flags are the only way to drive a screen. Always strip them before
  committing.
- **`.clipped()` clips drawing, not hit testing.** A `scaledToFill` thumbnail's invisible overflow
  stole taps from the camera cell for a whole night. `.contentShape(.rect)` is the fix, and the
  general rule is in CLAUDE.md under "A frame does not stop a view receiving touches".
- **`BrandFont.ui` scales with Dynamic Type**, because `Font.custom(_:size:)` does. Use
  `BrandFont.uiFixed` for marks and glyph-like text only.
- **`ViewThatFits` cannot see a compressible subtree.** The onboarding hero's centring `Spacer`s
  make its ideal height compressible, so the first option always "fits" and content clips.
- **`.background()` bleeds into the safe area by default.** Right for the full-bleed bands, wrong
  for any control near an edge.

## Credentials, and what not to commit

`Config/Secrets.xcconfig` and `Config/PostHogCLI.env` are gitignored and hold live values. Only the
`.example` files are tracked. `posthog-cli` is installed at `~/.posthog/posthog-cli` (a `--prefix`
install; a plain `npm -g` fails on the `/usr/local` prefix) and is authenticated — a real dSYM
upload has been verified end to end.

End commits with:

```
Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
```
