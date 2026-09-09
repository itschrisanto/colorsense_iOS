# ColorSense iOS — handoff

Written 2026-09-05 and updated 2026-09-07. Chris's Apple Developer Program enrollment is active.
This is what you need to pick the project up.

## Read these first, in this order

1. **`docs/STOREKIT-RESUME-2026-09-07.md`** — the exact physical-device StoreKit checkpoint, account
   state, completed evidence and first steps for resuming the Pro Pass test.
2. **`CLAUDE.md`** in the repo root. It is long and it is load-bearing — decisions, reversals, and
   the reasons behind both. Do not skim it. Most "obvious improvements" you might reach for have
   already been tried and are recorded there with why they failed.
3. **`docs/APP-STORE-SUBMISSION.md`** — the submission checklist and the drafted App Store Connect
   metadata. This is the file to work from once the account exists.
4. **`docs/PRIVACY-AUDIT.md`** — an evidence-backed audit of what the shipping build actually does.
   It is the **baseline**, and section 8c of the submission doc says it must be re-run against the
   final archived Release build.
5. **The vault**, at
   `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Daily Notes/Knowledge Base/Claude Skill.md`.
   It owns pricing, brand, voice and positioning. Read it fresh rather than trusting a copy. If it
   and this repo disagree, the vault wins.

## Repo state

The latest remote handoff before today's local checkpoint is `81f69b2`. The 2026-09-06 and
2026-09-07 implementation, StoreKit, privacy, appearance, export and submission-preparation work is
captured in the next local checkpoint commit. **135 tests across 26 suites pass**, most recently
rerun during the 2026-09-07 StoreKit work (0 failed, 0 skipped). Also on the remote:
`diagnostics/photo-picker-repro`, a reproduction harness for the photo
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
- **Appearance preference.** Account offers System, Light and Dark; the choice applies to the
  whole app immediately and persists locally across launches.
- **Camera permission recovery.** Camera access is requested only after a camera action. A denial
  now produces a camera-specific explanation with a direct route to the app's system Settings.
- **Analytics and error tracking.** Narrow by design. `AnalyticsService` is the whole contract.

Two things in there are settled and often get re-litigated: the primary button is **white on coral**
even though the app's own checker rates that POOR, deliberately and at Chris's call; and the
Extractor stays on the dock rather than in the tool strip because it returns a palette and closes.

## Chris's tool feedback, fixed 2026-09-06

- **Contrast and Palette Health fixes no longer blank or disappear after Apply.** The proposal list
  is captured in a `ContrastFixSheet.Session` when the sheet opens instead of being recomputed from
  state that Apply changes. Palette mutations target the swatch's UUID and expected hex rather than
  a stale array index, and refuse to overwrite a color that changed while the sheet was open.
- **Contrast Apply now updates the shared palette** when Text was selected from a palette swatch,
  preserves the swatch identity and lock, updates its anchor, and persists it. A color chosen in
  the system picker remains checker-only because it does not identify a palette slot; the fix sheet
  says so. Palette Health uses the same identity-safe shared-store path.
- **SVG Recolor has Shuffle colors.** It permutes the colors already mapped onto the SVG without
  changing or generating palette colors. Recoloring now replaces original tokens atomically, so a
  red/blue swap cannot collapse both into one color through sequential replacement.
- **SVG Recolor and Visualizer export PNG images and SVG files.** The shared export sheet has real
  preparation, error, and retry states instead of silently hiding a failed file. PNGs render locally
  at a 2048px long edge through WebKit's vector output; JavaScript and external loads remain blocked.
  Tests render every Visualizer scene and sample actual pixels so a blank or undersized image fails.

## Apple Developer work now unblocked

Work `docs/APP-STORE-SUBMISSION.md`. The order that matters:

The App Store Connect record was created on 2026-09-06 as **ColorSense: Palette Studio** under
Chrisanto Mendez. Its Apple ID is `6809134374`, bundle ID `online.colorsense.ios`, and SKU
`colorsense-ios-001`. Apple created an iOS 1.0 listing, and the project now matches it with
`MARKETING_VERSION = 1.0`.

StoreKit records were created on 2026-09-07: subscription group **ColorSense Pro** (`22363784`),
monthly (`6809206814`, $5.00), annual (`6809207967`, $39.00), and consumable Pro Pass
(`6809208412`, $9.00). All use the existing `online.colorsense.ios.pro.*` product IDs and worldwide
availability. Monthly has the agreed free one-week introductory offer with no end date. All three
products inherit the parent app's **App Store software** tax category, and their final App Review
notes were saved in App Store Connect on 2026-09-09. Three IAP review screenshots, with Monthly,
Annual and Pro Pass selected respectively, still have to be captured and uploaded. The StoreKit 2
client and Restore Purchases controls
are implemented behind `STOREKIT_PURCHASES_ENABLED`; keep it off until the backend passes sandbox
testing. The Paid Apps Agreement, banking information, Certificate of Foreign Status and W-8BEN
were all confirmed Active on 2026-09-07.

The six approved product-page screenshots were uploaded to App Store Connect on 2026-09-07. They
are 1290 x 2796 RGB PNGs without transparency and appear in order as palette, contrast, health,
visualizer, SVG and schemes. App Store Connect shows 6 of 10 in the 6.9" slot and derives the 6.5"
set from it. Build `1.0 (1)` was uploaded successfully on 2026-09-08, completed processing, and is
**Ready to Submit** in TestFlight. The app has not been added for review.

1. **Finish end-to-end Sign in with Apple testing.** Paid-team profiles and signed products carry
   the entitlement. Apple credentials and the iOS bundle were saved in the existing Replit-managed
   production Clerk tenant, and the production SSO pane showed Apple and Google enabled on
   2026-09-07. A Release-configuration build installed on the physical iPhone and reached Apple's
   native authorization sheet with both Share My Email and Hide My Email. The Share My Email flow
   then completed: signed-in Account loaded and a test palette saved and appeared in Library through
   the production API. Returning-user behavior also passed: after sign-out, Continue with Apple
   reopened the same account and the saved palette remained in Library. Cancellation passed in
   TestFlight build `1.0 (2)` on 2026-09-09: the Apple sheet reached Face ID and cancelling returned
   control without signing in or trapping the UI. That phone still receives Apple's returning-user
   sheet, but ColorSense is absent from its Apple Account revocation list; do not sign the main
   phone out of iCloud to force a reset. Complete Hide My Email and relay delivery with the first
   external tester whose Apple Account has never authorized ColorSense, using the matrix in
   `docs/replit-sign-in-with-apple-handoff.md`.
2. **Deploy StoreKit server reconciliation.** The StoreKit 2 client now loads localized products,
   purchases monthly, annual and the consumable pass, retries unfinished delivery, and provides
   Restore Purchases. It fetches the backend-issued app-account UUID before every new purchase and
   passes it to StoreKit as `.appAccountToken`. `GET /api/me` remains the entitlement source. The
   gate is enabled in the gitignored local configuration for physical-device acceptance testing;
   do not submit a release until the remaining sandbox and lifecycle tests pass. The production
   account-token and transaction routes were externally verified
   on 2026-09-07 to require authentication, and the public notification route rejected an empty
   probe as an invalid signed payload. This proves route deployment, but not real Apple signature
   verification, migrations or entitlement reconciliation. Later that day, a physical-device
   Monthly Sandbox purchase changed a newly created ColorSense account from Free to Pro after the
   seven-day trial confirmation, and Pro persisted after force-quit and relaunch. This proves
   signed-transaction delivery, backend persistence and `/api/me` activation. Restore Purchases
   then replayed successfully on the owning account without changing its Pro state. Replit later
   confirmed two Sandbox periods, valid ownership binding and final expiration at 07:56 Macau time;
   both the web and iOS correctly reported Free after expiration. Renewal/expiration passed. An
   Annual Sandbox purchase subsequently showed a generic local verification error after
   Apple confirmation, then Restore Purchases reconciled it and activated Pro. Annual backend
   activation passed. The client race was repaired on 2026-09-09: `ProStore.reconcile` now retries
   its injected `/api/me` reader after 250 ms, 500 ms and 1 second, while keeping the transaction
   unfinished until paid access is confirmed. Regression tests cover eventual Pro and bounded
   all-Free responses; the full 138-test simulator suite passed. TestFlight build `1.0 (3)` was
   archived and uploaded successfully on 2026-09-09. Apple finished processing it, marked it
   **Ready to Submit**, and distributed it to **ColorSense Internal**. Its archived dSYM UUID is
   `4FB029B4-222E-3541-B065-76BB69569F2C`, and PostHog has that symbol set under
   `online.colorsense.ios@1.0+3` with no failure. A fresh Monthly Sandbox purchase in build 3
   activated Pro directly without Restore and remained Pro after force-quit and relaunch, so the
   repaired immediate callback passed physical-device acceptance. While Annual was
   active, restoring from a second Free ColorSense account was rejected and left it Free, proving
   live ownership protection. The deployed endpoint returned `403`; the iOS client now presents
   the explicit account-ownership message for that response, verified on-device. Pro Pass was then
   purchased with a clean Sandbox tester: it activated Pro, persisted after force quit/relaunch and
   restored through the backend-entitlement fallback added for finished consumables. Replit
   confirmed one correctly bound transaction, an exact 31-day grant, idempotent duplicate delivery
   and effective Pro from `/api/me`. Pro Pass passed. Real Apple notification attempts initially
   returned `400`; Replit fixed and deployed the Version 2 handler, then Apple's Sandbox test and
   status APIs reported `SUCCESS`, HTTP `200`, verified JWS/bundle ID and no entitlement changes for
   the `TEST` event. The notification transport and verification blocker is closed.
3. **Finish the three In-App Purchase review records.** App Store Connect was rechecked on
   2026-09-09. Monthly, Annual and Pro Pass are available in all 175 countries or regions, inherit
   the parent app's **App Store software** tax category, and now have final product-specific review
   notes. Their three clean Free-account **Account → Subscription** review screenshots were uploaded
   to the matching records on 2026-09-10. The dedicated Free demo account was validated on-device;
   its credentials and contact information are saved only in App Store Connect. Do not add any
   product for review until the final build is selected for submission.
4. **Fix account deletion.** The app calls Clerk's `user.delete()` and nothing else, so the
   ColorSense Postgres row and every saved palette survive. This is a backend job — a verified Clerk
   `user.deleted` webhook — and the in-app copy currently claims otherwise. The implementation brief
   is **`docs/replit-account-deletion-handoff.md`** (2026-09-09); section 8c has the wider plan.
   Two things in that brief are not in the privacy audit and change the shape of the work: the
   cascade from `users` reaches only three tables, so Telegram links, voucher redemptions and
   feedback need explicit decisions rather than being assumed gone; and `requireAuth`/`optionalAuth`
   create the user row lazily on any authenticated request, so the webhook on its own leaves a race
   that can recreate the row and fire a Loops welcome email at somebody who just left.
   **Do not change `/api/saved-palettes` or `/api/me` contracts.**
5. **Re-run the privacy audit** against the final archived build, then finalise the policy and the
   App Store questionnaire in the order section 8c gives. The copy-ready Replit website brief for
   both legal pages is `docs/replit-website-legal-handoff.md`.
6. **Keep version numbers aligned.** The first App Store version and `MARKETING_VERSION` are `1.0`.
   `CURRENT_PROJECT_VERSION` is `4` for the Subscription accessibility build and must increment on
   **every** later upload — App Store Connect rejects a reused build number, and PostHog binds each
   dSYM to the release those numbers name.

## Release preparation completed 2026-09-06

- **Compact onboarding layout:** the outer viewport drives a compact composition below 740pt.
  Smaller decorative strips and mascot frames keep the signed-out account paragraph and all three
  actions in view on the SE. Hello, naming, mood and all three plan cards fit too. At
  accessibility-extra-large the hero scrolls while the actions remain visible. Standard SE and
  dark accessibility captures are in `.build/release-prep/`.
- **The vault is reconciled:** `Claude Skill.md` sections 3 and 22 now record the agreed 7-day iOS
  trial (awaiting StoreKit), seven tools, Schemes landing, Website Analyzer deferred, Brand Kit
  waiting on demand, current Pro surfaces, and StoreKit as a release requirement.
- **Six App Store screenshots:** native 1320 × 2868 PNGs in `docs/app-store/screenshots/` and a
  review gallery at `docs/app-store/index.html`. They use sample content, including original
  geometric SVG artwork. Temporary capture routes and Pro presentation overrides were removed
  from the source after capture. Review against the final release before upload.
- **Paid-team signing preflight:** Xcode automatically provisioned `online.colorsense.ios`, built
  and launched Debug on the paired iPhone, archived Release, and exported an App Store Connect IPA.
  Both signed apps carry Sign in with Apple; the export also carries `beta-reports-active` and has
  `get-task-allow` disabled. Build `1.0 (1)` was accepted by App Store Connect on 2026-09-08, and
  its exact archived dSYM is verified in PostHog.
- **Build 4 release package:** all 139 tests across 26 suites passed on 2026-09-10. The local
  `1.0 (4)` Release archive and App Store-signed IPA succeeded with StoreKit enabled, four embedded
  privacy manifests, Sign in with Apple, `beta-reports-active`, and `get-task-allow` disabled. The
  app binary and dSYM UUID both equal `49F6D3A0-76BB-3874-8C1A-8977C894AF9A`. The PostHog CLI
  accepted the upload for `online.colorsense.ios@1.0+4` without error; confirm it in the dashboard
  after processing. App Store Connect accepted the build-4 upload at 05:34 UTC on 2026-09-10 and
  reported that package processing had begun. The exported IPA remains available locally.

Physical-device accessibility follow-up completed on 2026-09-10 with build 4 on the connected
iPhone 17 Pro Max at the largest accessibility text setting. The signed-in account **Continue** and
all three plan actions remained visible; tapping **Not now** returned to the main palette.
The **ColorSense Internal** TestFlight group was created on 2026-09-08 with automatic distribution,
Chris's App Store Connect Apple ID as its one tester, and build `1.0 (1)` as its one build. On
2026-09-09, the tester initially showed **No Builds Available** and no email arrived. Saving the
build's previously blank **What to Test** field refreshed distribution. Chris accepted the invite,
installed from TestFlight, and App Store Connect records **Installed 1.0 (1)** on the physical
iPhone. The onboarding and main feature sweep passed after deleting retained data from the earlier
Xcode-installed build. A Sandbox Monthly purchase immediately activated Pro and stayed active after
force-quit and relaunch. Explicit Restore then failed twice because `AppStore.sync()` threw before
the client checked the already-active backend entitlement. That control flow is repaired and
covered by two focused tests; all 137 tests across 26 suites pass. Build `1.0 (2)` was archived and
uploaded on 2026-09-09 and finished processing. Its PostHog release is `online.colorsense.ios@1.0+2` with
dSYM UUID `6BD22D4C-71B9-3C8C-B7C8-C6FAFE0E9B77`, an uploaded file and no failure. Chris installed
build 2 and confirmed “your purchase restored,” completing the purchase/persistence/restore smoke
test. Build `1.0 (3)` contains the immediate-purchase retry, is **Ready to Submit**, and is available
to **ColorSense Internal** with focused **What to Test** instructions. Its PostHog dSYM upload is
also verified. Chris installed it, made a fresh Monthly Sandbox purchase from a new Free account,
and confirmed immediate Pro activation plus persistence after relaunch. The first attempt exposed a
TestFlight setup detail: **Media & Purchases** must be signed out before the Sandbox Apple Account
selected under **Developer** is used. Account-deletion verification is explicitly parked. The
three Sandbox Apple Accounts remain StoreKit-only test identities. App Store Connect still needs
selection of the final build and the final privacy questionnaire. Apple accepted build `1.0 (4)`
for processing; assign it to the internal group once processing finishes.

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
- **iPad is deferred with a trigger, and iPhone-only is the 1.0 decision** (2026-09-09). Do not flip
  `TARGETED_DEVICE_FAMILY` to `"1,2"`. It is one character and it is the worst outcome available:
  the listing advertises iPad while the binary delivers a stretched phone layout, and review checks
  iPad layout on universal apps. The trigger for reopening it is a device split from the web's own
  analytics or from App Store Connect after launch, not a hunch about the market. CLAUDE.md's
  "iPad is deferred, and the deferral has a trigger" lists what a real layout would cost.
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
install; a plain `npm -g` fails on the `/usr/local` prefix) and is authenticated. It was updated to
0.18.1 on 2026-09-08. The TestFlight `1.0+1` archive dSYM was uploaded and verified in PostHog:
UUID `D63B0BF1-D556-3B38-AE4A-E6F485B5B34F`, one matching symbol set, uploaded file present, no
failure reason, and release binding `online.colorsense.ios@1.0+1`. Downloading the symbol set back
from PostHog produced a DWARF file with the same UUID and SHA-256 hash as the archive.

End commits with:

```
Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
```

## Latest verification evidence

- Final checkpoint suite: 135 passed, 0 failed, 0 skipped on ColorSense-SE, iOS 26.5, on
  2026-09-07. XcodeBuildMCP reported no warnings or diagnostics.
- The Appearance control was exercised live in the open Account sheet: Light to Dark and Dark to
  System both applied immediately without dismissing the sheet. The simulator preference was left
  on System.
- Camera permission request, denial explanation and the Open Settings recovery route were exercised
  in the simulator. The earlier `resumeOnce()` Swift concurrency warnings were fixed.
- Screenshot dimensions verified from each PNG header: six images, all 1320 × 2868.
- No `QA_BEAT`, `QA_TOOL`, sample SVG injection, or Pro presentation override remains in app source.
- Paid-team Debug built, installed and launched on the paired iPhone. A signed Release archive and
  App Store Connect IPA export succeeded with Sign in with Apple. Apple accepted build `1.0 (1)`
  on 2026-09-08; processing completed, and the internal group now reports it **Ready to Test** for
  its first tester.
- The physical-device smoke test passed for Appearance switching, camera extraction, StoreKit Pro
  restore and persistence, PNG export to Photos, and the contrast smart fix. The signed `1.0+1`
  archive's matching dSYM is present in PostHog and bound to the correct release.
