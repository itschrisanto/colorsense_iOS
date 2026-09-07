# ColorSense iOS — App Store submission

The reference for getting this app into review, and the record of why each decision was made.
Written 2026-09-05 and updated 2026-09-07 after the App Store Connect record was created.

**Facts here that belong to the brand — pricing, positioning, handles, contact — are owned by the
vault** (`Claude Skill.md`), not by this file. Where copy is drafted below it is drafted *from* the
vault; if the two ever disagree, the vault wins and this file is stale.

---

## 1. Where things stand

**The shared backend is in production.** The Express API at `colorsense.online/api`, Postgres
through Drizzle, Clerk auth on the production instance, and PostHog analytics with error tracking
serve both clients. The StoreKit 2 client is implemented behind a release flag; Apple purchase
reconciliation on the backend and verified account deletion are still required.
iOS is a client of the same stack the web app uses, verified end to end on a physical iPhone: email
and Google sign-in, saving a palette to the account, and the palette appearing on colorsense.online.

**The app is built.** Seven tools ship: Extractor, Contrast, Health, SVG Recolor, Visualizer,
Schemes and Library, plus onboarding, the palette workspace, Account, About and Feedback.
135 tests across 26 suites pass.

**Apple Developer Program enrollment is active.** Automatic provisioning now produces signed Debug
and Release builds. The App Store Connect record exists and its six approved iPhone screenshots are
uploaded; the build, review information, privacy questionnaire and release blockers remain. See
section 2.

---

## 2. Apple account setup

- [x] Apple Developer Program enrollment active (confirmed 2026-09-06)

- [x] Register/provision the App ID `online.colorsense.ios`. Xcode created paid-team development
      and distribution profiles for it on 2026-09-06.
- [x] Provision **Sign in with Apple** for that App ID. The entitlement is enabled for Debug and
      Release and is present in signed products.
- [x] Register the iOS bundle and Apple credentials in the Replit-managed production Clerk tenant
      and enable Apple for sign-up and sign-in (confirmed in the production SSO provider pane on
      2026-09-07). Google remains enabled. End-to-end Apple sign-in tests remain; use
      `docs/replit-sign-in-with-apple-handoff.md` for the test matrix.
- [x] Confirm the Apple option reaches Apple's native authorization sheet on the physical iPhone.
      Both **Share My Email** and **Hide My Email** were presented on 2026-09-07. Completing sign-in,
      Clerk/API access and returning-user behavior passed; cancellation, Hide My Email and the
      relay-email flow remain to test.
- [x] Complete the first-user **Share My Email** path on the physical iPhone (2026-09-07). Apple
      authorization completed, the app reached its signed-in Account state, account data loaded,
      and a test palette saved and appeared in Library. This proves the Apple-created Clerk session
      works with the production ColorSense API.
- [x] Complete the returning-user Apple path on the physical iPhone (confirmed 2026-09-07).
      Signing out and choosing Continue with Apple reopened the same ColorSense account, and the
      previously saved palette remained in Library. Cancellation, Hide My Email and relay delivery
      remain.
- [x] Create the App Store Connect record. Created 2026-09-06 as **ColorSense: Palette Studio**
      under Chrisanto Mendez; Apple ID `6809134374`, bundle ID `online.colorsense.ios`, SKU
      `colorsense-ios-001`, primary language English (U.S.), Full Access.
- [x] Create the StoreKit products (section 3). The records were created on 2026-09-07; review
      review screenshots and server reconciliation remain.
- [x] Produce a signed Release archive and App Store Connect export. The preflight archive and IPA
      were created on 2026-09-06 with automatic signing; nothing was uploaded.

Verification on 2026-09-06: a paid-team Debug build installed and launched on the paired iPhone;
the Release archive succeeded; and `xcodebuild -exportArchive` produced an App Store Connect IPA.
The exported app has `com.apple.developer.applesignin`, `beta-reports-active = true`, and
`get-task-allow = false`. The archive contains `ColorSense.app.dSYM`. PostHog ran in dry-run mode to
avoid attaching a second symbol set to the historical `0.1.0+1` release. The project now targets
`1.0+1`; a fresh archive is required before upload.

---

## 3. StoreKit, and why it gates submission

`Services/ProStore.swift` is the client seam; every screen offering Pro already calls through it.
The app's actual entitlement source is the shared backend's `GET /api/me`, so client StoreKit code
alone is insufficient. A verified Apple transaction has to update the server-side entitlement before
the app reports a purchase as complete. The Pro Pass especially needs server storage because a
consumable does not appear in `Transaction.currentEntitlements` after it is finished.

- [x] **Pro Monthly $5/mo and Pro Annual $39/yr in ONE subscription group.** Created in
      **ColorSense Pro**, group ID `22363784`, with worldwide availability and exact U.S. base
      prices of $5.00 and $39.00. Monthly Apple ID `6809206814`; annual Apple ID `6809207967`.
      Two groups means a
      reader cannot switch without double-paying.
- [x] **Pro Pass $9 is a consumable, not a subscription**, and is outside that group. Created with
      worldwide availability, exact U.S. base price $9.00, and Apple ID `6809208412`. It is a
      one-month, one-time purchase that can be bought again once it lapses, which a non-consumable
      cannot. Getting this wrong is a wrong product in App Store Connect, replaced rather than
      edited. `ProProduct.kind` records it.
- [x] Attach the trial as an **introductory offer on the monthly product**. A free one-week offer is
      active from 2026-09-07 with no end date in all 175 countries or regions, matching the agreed
      7-day iOS trial in the vault.
- [x] Confirm the **Paid Apps Agreement** is Active in Business and that banking and tax information
      are complete. The agreement, bank account and both required U.S. forms—the Certificate of
      Foreign Status and W-8BEN—were confirmed Active on 2026-09-07. Apple requires the agreement
      to be Active even for sandbox purchase testing.
- [ ] Confirm the In-App Purchase **tax category** for all three products.
- [ ] Add the required App Review screenshots and final review notes to all three StoreKit records.
- [ ] Add a signed-transaction endpoint and Apple subscription lifecycle handling to the shared
      backend. Keep `GET /api/me` as the source of truth and make transaction processing idempotent.
      The implementation brief is `docs/replit-storekit-backend-handoff.md`. Replit reported the
      transaction and account-token routes implemented in development on 2026-09-07. The production
      deployment was externally verified the same day: both authenticated routes return `401`
      without a Clerk session, while `POST /api/webhooks/apple/app-store` returns `400 Invalid
      signed payload` for an empty body. A physical-device Sandbox purchase then proved real
      signed-payload processing: a new Free account purchased Monthly with the seven-day trial and
      `/api/me` changed to Pro. The entitlement remained Pro after force-quitting and relaunching the
      app, proving backend persistence. Restore Purchases then replayed the subscription on the
      owning account and returned “Your purchase was restored” while remaining Pro. Replit then
      confirmed two Sandbox periods, valid ownership binding to the purchasing Clerk account and a
      final expiration at 2026-09-07 07:56 Macau time; the web correctly reported Free afterward.
      The purchasing account also reported Free in iOS after signing back in, confirming both
      clients honor the expired backend entitlement. An Annual Sandbox purchase later
      produced the generic local verification error immediately after Apple confirmation, but
      Restore Purchases reconciled the active Annual entitlement and changed the owning account to
      Pro. Annual product/backend activation therefore passed; the immediate callback discrepancy
      remains to diagnose. While Annual was active, restoring it from a second Free ColorSense
      account was rejected and the second account remained Free, proving live ownership protection.
      The deployed endpoint returned `403`; the iOS client now maps that response to the explicit
      account-ownership message, verified on-device. Pro Pass was then purchased with a clean
      Sandbox tester on the second ColorSense account: Apple confirmation activated Pro, Pro
      persisted after force quit and relaunch, and the corrected backend-entitlement fallback made
      Restore Purchases succeed for the finished consumable. Replit confirmed one correctly bound
      Sandbox transaction, an exact 31-day grant from 2026-09-07 05:15:26 UTC through 2026-10-08
      05:15:26 UTC, duplicate submissions that returned `200` without extending the grant, and an
      effective Pro plan from `/api/me`. Pro Pass acceptance therefore passed. Real Apple
      notification attempts around the purchase initially returned `400`. Replit fixed and deployed
      the Version 2 handler; Apple Sandbox Request a Test Notification and Get Test Notification
      Status then reported `SUCCESS`, the callback returned `200`, JWS and bundle ID verification
      passed, and the `TEST` event changed no transaction or entitlement counts. The notification
      transport and verification blocker is closed.
- [x] Generate a separate **In-App Purchase key** in Users and Access → Integrations → In-App
      Purchase, then put its private key, key ID and issuer ID in Replit Secrets. The key was
      generated, its one-time `.p8` download was secured, and the required secret values were added
      to Replit on 2026-09-07. This is separate from the Sign in with Apple key.
- [x] Add the production and sandbox notification URLs under App Information → App Store Server
      Notifications. Both were configured on 2026-09-07 as Version 2 using
      `https://colorsense.online/api/webhooks/apple/app-store`.
- [x] Complete the EU Digital Services Act declaration. ColorSense was declared a trader for its
      commercial EU distribution and the required contact verification was completed on 2026-09-07.
- [x] Write `StoreKitProStore`, submit the verified transaction to that endpoint, refresh `/api/me`,
      and only then report `.purchased`. The client also retries unfinished transactions on launch,
      takes localized prices and introductory-offer eligibility from StoreKit, and validates the
      configured product type. Before each new purchase it fetches the backend-issued UUID from
      `GET /api/iap/apple/app-account-token` and passes that exact value through StoreKit's
      `.appAccountToken` purchase option. It is protected by `STOREKIT_PURCHASES_ENABLED`, which
      is `YES` in the gitignored local configuration for physical-device acceptance testing.
- [x] **Add a Restore Purchases control.** Both onboarding and Subscription have an explicit
      restore action. It calls `AppStore.sync()` only after the reader taps it and restores active
      subscriptions; the consumable pass is restored by the shared server entitlement.

**The onboarding plan beat stays in the flow** (decided 2026-09-05). Its monthly and annual actions
now use StoreKit, with the seven-day copy shown only when StoreKit reports that the Apple account is
eligible. **The app still cannot be submitted until the remaining sandbox and lifecycle tests pass.**

**Pro is sold through Lemon Squeezy on the web.** On iOS the same tiers must go through In-App
Purchase. Never link to a Lemon Squeezy checkout from inside the app, and never add copy pointing at
where to buy on the web — that is the same rule that already removed "Pro is available at
colorsense.online" and that keeps the About screen's Support row out.

---

## 4. Settle before uploading

- [x] **Decide the real version number.** The first App Store version and `MARKETING_VERSION` are
      both `1.0`; `CURRENT_PROJECT_VERSION` is `1`. Both are hand-edited in `project.yml`; nothing
      bumps them automatically.
- [ ] **Increment `CURRENT_PROJECT_VERSION` on every upload**, including re-uploads of the same
      marketing version. Two independent reasons: App Store Connect rejects a reused build number,
      and PostHog binds each uploaded dSYM to the release these numbers identify, so two builds at
      one version collide and either fail the build or silently attach the wrong symbols.
- [x] **`posthog-cli` is authenticated, and the upload is proved end to end (2026-09-05).**
      `Config/PostHogCLI.env` holds a personal API key and the project ID; it is gitignored and
      untracked, verified both ways. A real Release build with `CODE_SIGNING_ALLOWED=NO` created the
      release `online.colorsense.ios@0.1.0+1` in PostHog and uploaded the dSYM
      (UUID `6BE7EC1E-6480-355E-ADF8-432064FC5B42`, 17.8MB, 1 chunk, 0 skipped). This was the last
      unproven link in the chain — everything before it had only been dry-run.
      **That release name makes the version problem concrete rather than theoretical.** A symbol set
      now exists against `0.1.0+1`, so the next Release build at the same numbers with a different
      binary collides. See the version item above; that is its second reason.
- [x] **Checked the layout on an iPhone SE (2026-09-05), and it was broken.** Measured: the
      onboarding band stack laid out at **906.5pt on a 667pt screen** in the account ask's
      signed-out shape, and the overflow was clipped, taking "Maybe later" with it. That control is
      the guideline 5.1.1(v) exit, so it was a submission blocker, not a cosmetic one. Fixed by
      making the hero a scroll view with a floor of its own viewport, so it centres when there is
      room and gives way when there is not.
- [x] **Finish the compact onboarding layout** (2026-09-06). An outer GeometryReader measures the
      actual screen, with smaller strips, mascot frames and spacing on screens below 740pt.
      The signed-out account paragraph and all three controls fit on the 375 × 667 SE without
      scrolling. The account beat also uses 60pt strips on taller phones to recover hero space.
- [x] **Sweep the flow on an SE** (2026-09-06). Hello, naming, mood, account and plan were captured
      and visually checked at standard text size. Account, mood and plan were also checked in dark
      appearance at accessibility-extra-large: action controls and exits stay visible, with hero
      content in the scroll fallback. Evidence: `.build/release-prep/se-*.png`.
- [ ] **Physical-device follow-up:** verify scrolling through the accessibility hero content and
      tapping each exit. Simulator screenshots prove visibility, not touch or scroll behavior.
- [ ] **Re-check `PrivacyInfo.xcprivacy` if any package version moved.** It covers the whole package
      graph: ClerkKit/ClerkKitUI and Nuke ship no manifest of their own and are linked statically,
      so their API use is ours to declare. PostHog and PhoneNumberKit ship their own. Apple's scan
      only runs server-side at upload, so the first upload is the real test.

---

## 5. App Store Connect record — drafted metadata

Drafted from the vault. **Brand name rule: always `ColorSense`** — capital C, capital S, one word.
Never "Colorsense", "Color Sense", or "ColorSense.online" in copy.

| Field | Value |
|---|---|
| Name | ColorSense: Palette Studio |
| Subtitle | Image color palette generator |
| Bundle ID | `online.colorsense.ios` |
| Primary category | Graphics & Design |
| Secondary category | Photo & Video |
| Age rating | 4+ |
| Support URL | https://colorsense.online |
| Marketing URL | https://colorsense.online |
| Privacy Policy URL | https://colorsense.online/privacy-policy |
| Copyright | 2026 Chrisanto Mendez |
| Contact | hello@colorsense.online |

Saved in App Store Connect on 2026-09-07: subtitle; Graphics & Design primary and Photo & Video
secondary categories; 4+ age rating; content-rights confirmation; privacy-policy URL; description;
keywords; support and marketing URLs; copyright; and manual release. Promotional text remains blank.
The app download is free and public in all 175 countries or regions. Automatic distribution on Mac
and Apple Vision Pro is off because the iPhone build has not been tested there. Six approved iPhone
screenshots were uploaded in order on 2026-09-07. The build, review credentials and final privacy
questionnaire remain unset.

**Keywords** (100 characters, comma separated, no spaces after commas, no words already in the name
or subtitle): `palette,hex,wcag,contrast,accessibility,designer,swatch,brand,photo,extract,svg,mockup`

**Description draft.** Voice rules from vault section 9 apply: specific and grounded, no em dashes
or en dashes anywhere a reader can see them, American spelling, color words in caps where they name
a colour.

> Pull a palette out of any photo, then put it to work.
>
> ColorSense extracts the colors from a picture on your device and hands you a palette you can edit,
> lock, shuffle and keep. Every color is named. Every pairing can be checked against WCAG contrast
> before you ship it.
>
> Extract from a photo or the camera. Five colors, named, in a second.
> Check contrast to AA and AAA, with a plain reading of what passes and what does not.
> Score a palette across five dimensions and see exactly which pairing is letting it down.
> Recolor an SVG with your palette and export it.
> See the palette on real work: interfaces, branding, packaging, charts and posters.
> Save to your account and it is on colorsense.online too.
>
> The extractor and the contrast checker are free and unlimited, and they always will be. Both run
> entirely on your device.

**What's New (first release):** first release copy, written at submission.

**Promotional text (170 chars, editable without review):** hold for launch.

---

## 6. App Privacy questionnaire

Must match the app and every bundled SDK. Answers, with the reasoning:

**Data linked to the user** (through the Clerk account):
- Contact Info — email address, name. Clerk, for authentication.
- User Content — saved palettes and color names, via `/api/saved-palettes`.
- Identifiers — user ID.

**Data not linked to the user:**
- Usage Data — Product Interaction, Other Usage Data. PostHog, using only its random installation
  ID. `identify()` is never called, which is what keeps PostHog's own manifest declaration of
  *unlinked* collection true. Identifying users would silently make that declaration false.
- Diagnostics — Crash Data, Other Diagnostic Data. PostHog error tracking and PHPLCrashReporter.
  Fatal reports carry stack traces and technical diagnostics, and no breadcrumbs, logs, hex values,
  palette names or photos.

**Used for tracking: none.** Nothing is shared with data brokers or used for cross-app advertising.

**Photos are never collected.** The library is read on device to build the picker and to extract a
palette; no image is uploaded, copied or retained.

---

## 7. Screenshots

Apple requires the 6.9" iPhone set; other sizes are derived from it. Capture from a simulator whose
logical size matches, with the status bar cleaned up.

- [x] 6.9" iPhone — 1320 x 2868. Six checked captures in `docs/app-store/screenshots/`;
      open `docs/app-store/index.html` to review. Recheck against the final release before upload.
- [x] Upload the approved six-image product-page set to App Store Connect (2026-09-07). The final
      files are 1290 x 2796 RGB PNGs without transparency, accepted by the 6.9" display slot in
      filename order: `01-palette`, `02-contrast`, `03-health`, `04-visualizer`, `05-svg`,
      `06-schemes`. App Store Connect shows 6 of 10 and derives the 6.5" set from them.
- [ ] 6.5" iPhone — 1242 x 2688, only if targeting that display class explicitly

Suggested order, leading with what the app is rather than with chrome: the palette bands; extraction
from a photo; the contrast checker on a real pairing; Palette Health with its report; the Visualizer
showing a scene; SVG Recolor.

---

## 8. After the first upload

- [ ] Confirm the archive carries the production PostHog token and host, launch it, and verify
      `app_opened` reaches the dashboard.
- [ ] Verify the dSYM appears in PostHog Symbol sets.
- [ ] Trigger one controlled crash in an internal build, relaunch so the stored report uploads, and
      verify `$exception` arrives symbolicated, both reliability tiles move, and the Discord
      issue-created alert fires. **Remove the crash trigger before external distribution.**
- [ ] Read Apple's server-side privacy-manifest report and resolve any warning. That report is the
      authoritative aggregation, not our copy of it.
- [ ] Retention stays sparse until a second weekly cohort interval has elapsed. Expected, not a
      setup failure.

---

## 8b. Privacy audit (2026-09-05)

`docs/PRIVACY-AUDIT.md` is the evidence-backed audit of what the shipping build actually does,
claim by claim, with the App Store privacy labels and copy-ready policy wording derived from it.

**It found one blocker.** Account deletion calls Clerk's `user.delete()` and nothing else. The
`saved_palettes.user_id` foreign key cascades on delete, but nothing ever deletes the ColorSense
`users` row: there is no Clerk webhook route in the api-server and no `db.delete(usersTable)`
anywhere. So a deleted account leaves its database row and every saved palette in place, while
`DeleteAccountView` tells the user their palettes are removed. That claim must not be published,
and the app should not be submitted, until the backend cleanup exists.

Everything else audited came back accurate: photos never leave the device, the colour tools are
entirely local, analytics are pseudonymous with `identify` never called, the opt-out is set before
the SDK is configured so an opted-out install sends nothing at all, and there are no advertising,
attribution or tracking SDKs of any kind.

One claim needs qualifying rather than fixing: crash reports carry the exception's own message,
which we do not control, so "crash reports never contain user content" must not be said.

## 8c. Final privacy work (planned with Replit, 2026-09-05)

Developer access is active, but this work still belongs at final integration because it must be
tested against the build intended for submission. `docs/PRIVACY-AUDIT.md` is the **baseline**, not
the final word: it audited a development build, and the audit is to be re-run against the final
archived Release build and its dependency lockfile.

**1. Fix account deletion (blocker).** Add a *verified* Clerk `user.deleted` webhook to the
backend: match the Clerk user to the local Postgres user, delete that row, and confirm the existing
`saved_palettes.user_id` cascade removes the palettes. Webhook retries must be idempotent, and
unsigned or invalid requests must be rejected. Test deletion from **both** the iOS app and the
website, and confirm the Clerk identity, the local profile, the saved palettes and every other
account-linked row are actually gone. **Preserve the `/api/saved-palettes` and `/api/me` response
contracts.** Publish no deletion claim until this is proved end to end.

**2. Sign in with Apple.** App ID provisioning, entitlements and profiles are confirmed. Configure
the Clerk integration and callback, then test new
sign-in, returning sign-in, cancellation, relay email and deletion — **in an archived Release build,
not a development one**. If it will not ship, say "supported third-party sign-in providers"
everywhere and name Apple nowhere.

**3. Re-run the audit against the final build.** Reconfirm each finding rather than trusting this
one: photos and camera images stay on device, extraction and WCAG stay local, no image data,
metadata, thumbnail or filename is uploaded, PostHog stays pseudonymous and unlinked from Clerk, the
opt-out still disables the SDK before initialisation and persists, autocapture / screen tracking /
session replay / lifecycle / surveys / push all remain off, the event allowlist and properties have
not expanded, crash diagnostics still follow the opt-out, no advertising, attribution, IDFA, ATT or
new tracking SDK has appeared, and deletion now really removes server-side data. Flag anything that
cannot be proved from the final implementation.

**4. Finalise disclosures, in this order.** Only after the audit passes: update the policy with the
iOS wording, add the deletion paragraph **only** once deletion is verified end to end, name Sign in
with Apple only if it is live in the submitted build, make the website and in-app deletion copy
describe the same verified behaviour, complete the App Store Connect questionnaire from the final
build's actual collection, and confirm the privacy manifest and permission strings match.

**5. Production readiness.** Confirm the latest backend is published; confirm the production
database carries the composite saved-palettes index on `(user_id, created_at DESC)`; verify account
creation, palette sync, single-palette deletion, full account deletion, analytics opt-out and
authentication against production. **No test may modify real customer data without explicit
approval.**

**Final report to produce at that point:** files changed, the implemented deletion lifecycle,
evidence server-side data is removed, Sign in with Apple status, final PostHog configuration and
event list, final privacy-label recommendations, copy-ready policy wording, unresolved risks, and a
clear "safe to submit" or "not safe to submit". Do not weaken an existing privacy promise silently:
if one cannot be implemented or verified, stop and report the discrepancy before changing the
public wording.

## 9. Outside this repo

- [ ] **Add a Clerk `user.deleted` webhook to the api-server** so deleting an account actually
      deletes the ColorSense user row and, through the existing cascade, its saved palettes. Blocks
      submission. Do not change the `/api/saved-palettes` or `/api/me` response contracts; the app
      depends on both.
- [ ] **The web privacy policy never mentions mobile or iOS.** It is substantively accurate — same
      Clerk instance, same API, same data — but a reviewer checks that the policy covers the app.
      The website Terms also describe only the browser tool and omit accounts and App Store billing.
      Use `docs/replit-website-legal-handoff.md` for both pages when the Replit side is updated.
- [ ] **Add "Leave a review" to the About screen** the day the App Store record exists, with the
      real App ID. It is deliberately absent because it would currently go nowhere.
- [x] **Reconcile the vault with iOS scope** (2026-09-06). Section 22 now records the seven tools,
      Schemes landing, Website Analyzer deferred, Brand Kit waiting on demand, the current Pro
      surfaces, and StoreKit as a release requirement.
- [x] **Capture the App Store screenshots** at 6.9" (1320 x 2868), completed 2026-09-06.
      Six native screenshots and a review gallery are in `docs/app-store/`. A photo extraction
      image remains an optional addition using an approved sample photo.
- [x] **Reconcile the trial with the vault** (2026-09-06). Section 3 now records the agreed 7-day
      iOS introductory offer on Monthly, explicitly awaiting StoreKit configuration and eligibility checks.
