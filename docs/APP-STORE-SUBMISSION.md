# ColorSense iOS — App Store submission

The reference for getting this app into review, and the record of why each decision was made.
Written 2026-09-05 and updated through 2026-09-10 after the first internal TestFlight pass.

**Facts here that belong to the brand — pricing, positioning, handles, contact — are owned by the
vault** (`Claude Skill.md`), not by this file. Where copy is drafted below it is drafted *from* the
vault; if the two ever disagree, the vault wins and this file is stale.

---

## 1. Where things stand

**The shared backend is in production.** The Express API at `colorsense.online/api`, Postgres
through Drizzle, Clerk auth on the production instance, and PostHog analytics with error tracking
serve both clients. StoreKit purchase reconciliation and Version 2 notification verification have
passed against Apple's Sandbox. Verified account deletion and a real refund/revocation lifecycle
test are still required before App Store submission.
iOS is a client of the same stack the web app uses, verified end to end on a physical iPhone: email
and Google sign-in, saving a palette to the account, and the palette appearing on colorsense.online.

**The app is built.** Seven tools ship: Extractor, Contrast, Health, SVG Recolor, Visualizer,
Schemes and Library, plus onboarding, the palette workspace, Account, About and Feedback.
142 tests pass.

**Apple Developer Program enrollment is active.** Automatic provisioning now produces signed Debug
and Release builds. The App Store Connect record exists and its six approved iPhone screenshots are
uploaded. Build `1.0 (3)` finished processing and passed fresh Monthly purchase, immediate
activation, entitlement persistence and Restore Purchases checks on a physical iPhone. Review
credentials and TestFlight information are saved. Build `1.0 (4)`, containing the Subscription
accessibility fix, now has a verified Release archive and App Store-signed IPA. Apple accepted and
processed the upload on 2026-09-10; it is **Ready to Submit** and assigned to **ColorSense
Internal**. The privacy questionnaire and remaining release blockers still apply. See section 2.
Build `1.0 (5)`, containing the corrected privacy manifest and PostHog GeoIP controls, is
**uploaded and processed**, confirmed directly in App Store Connect on 2026-09-10. Build Uploads
shows **Complete**; the build is **Ready to Submit**, assigned to **ColorSense Internal**, with
one tester invited. This resolves the earlier interrupted-upload uncertainty. Its build ID is
`3a00ed51-2d1d-4276-b455-f3f4bcb22ed9`.

Its archive was verified locally on 2026-09-10, against
`.build/testflight/ColorSense-1.0-5.xcarchive`:

- `CFBundleShortVersionString` `1.0`, `CFBundleVersion` `5`, team `L53K68TJHL`.
- **The `-iap-review-*` screenshot scaffolding is absent from the shipped binary**, checked with
  `strings` rather than by trusting that it was removed from source, which is what section 3a asks
  for. It is also gone from the source tree.
- `ColorSense.app.dSYM` is present, so PostHog has symbols to bind to this release.
- `PrivacyInfo.xcprivacy` is at the bundle root.
- The production analytics configuration shipped: host `https://us.i.posthog.com`, project key
  present with the expected `phc_` prefix.
- The Clerk key is `pk_live_`, so Clerk telemetry stays off and the privacy manifest stays true. A
  development key here would silently start telemetry and make that manifest wrong.

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
      Clerk/API access, returning-user behavior and cancellation passed; Hide My Email and the
      relay-email flow remain to test. Cancellation was verified in TestFlight build `1.0 (2)` on
      2026-09-09: the native sheet reached Face ID, cancelling returned control without signing in,
      an error, or a stuck loading state. The same device shows Apple's returning-user sheet but
      ColorSense is absent from the Apple Account's revocation list, so its first-authorization
      Share/Hide choice cannot be safely reset there. Complete Hide My Email and relay delivery
      with the first external tester whose Apple Account has never authorized ColorSense.
- [x] Complete the first-user **Share My Email** path on the physical iPhone (2026-09-07). Apple
      authorization completed, the app reached its signed-in Account state, account data loaded,
      and a test palette saved and appeared in Library. This proves the Apple-created Clerk session
      works with the production ColorSense API.
- [x] Complete the returning-user Apple path on the physical iPhone (confirmed 2026-09-07).
      Signing out and choosing Continue with Apple reopened the same ColorSense account, and the
      previously saved palette remained in Library. Cancellation also passed in TestFlight build
      `1.0 (2)`; Hide My Email and relay delivery remain.
- [x] Create the App Store Connect record. Created 2026-09-06 as **ColorSense: Palette Studio**
      under Chrisanto Mendez; Apple ID `6809134374`, bundle ID `online.colorsense.ios`, SKU
      `colorsense-ios-001`, primary language English (U.S.), Full Access.
- [x] Create the StoreKit products (section 3). The records were created on 2026-09-07, and the
      three final product-specific review screenshots were uploaded by 2026-09-10.
- [x] Produce a signed Release archive and App Store Connect export. The preflight archive and IPA
      were created on 2026-09-06 with automatic signing; nothing was uploaded.
- [x] Upload and verify the matching PostHog dSYM for TestFlight build `1.0+1` (2026-09-08).
      PostHog reports one uploaded symbol set for UUID
      `D63B0BF1-D556-3B38-AE4A-E6F485B5B34F`, with no failure reason, attached to release
      `online.colorsense.ios@1.0+1`. The UUID matches both the app binary and the dSYM retained in
      `.build/testflight/ColorSense-1.0-1.xcarchive`. A download-back check also produced the same
      SHA-256 hash as the archived DWARF file.
- [x] Upload build `1.0 (1)` to App Store Connect (2026-09-08). Apple's upload validation passed
      and processing completed successfully. The Build Uploads row is **Complete**, and TestFlight
      version 1.0 build 1 is **Ready to Submit**. The uploaded app uses the App Store provisioning
      profile, includes Sign in with Apple and `beta-reports-active`, and has
      `get-task-allow = false`.
- [x] Create the internal TestFlight group **ColorSense Internal**, add Chris's App Store Connect
      Apple ID as the first internal tester, and assign build `1.0 (1)` (2026-09-08). The group has
      one tester and one build; the build is **Ready to Test**. Automatic distribution is enabled.
      Neither Sandbox Apple Account was used because those accounts are only for StoreKit testing.
- [x] Accept the internal invitation and install build `1.0 (1)` from TestFlight (2026-09-09).
      The tester initially showed **No Builds Available** and Apple sent no email. Saving the
      build's previously blank **What to Test** field refreshed distribution. App Store Connect now
      records **Installed 1.0 (1)** on the physical iPhone. The onboarding and main feature sweep
      passed after deleting retained data from the earlier Xcode-installed build.
- [x] Complete the TestFlight Monthly purchase and persistence checks in build `1.0 (1)`
      (2026-09-09). The Sandbox purchase completed, the signed-in ColorSense account immediately
      showed **Pro - Active**, and it remained Pro after force-quit and relaunch.
- [x] Diagnose and repair the explicit Restore Purchases failure from build `1.0 (1)`
      (2026-09-09). It reproduced twice because an `AppStore.sync()` error returned before the app
      checked StoreKit entitlements or the durable backend entitlement. Restore now continues both
      checks after a sync error and succeeds only when Apple or `/api/me` confirms paid access.
      Two focused regression tests cover the paid-account fallback and the free-account rejection;
      all 137 tests across 26 suites pass.
- [x] Archive and upload build `1.0 (2)` with the restore repair (2026-09-09). Apple's package
      upload succeeded and processing began. PostHog has the exact archive dSYM under release
      `online.colorsense.ios@1.0+2`, UUID `6BD22D4C-71B9-3C8C-B7C8-C6FAFE0E9B77`, with an uploaded
      file and no failure reason.
- [x] Complete the StoreKit purchase, entitlement persistence and Restore Purchases smoke test
      (2026-09-09). Purchase and persistence passed in build 1; after updating to build `1.0 (2)`,
      Chris confirmed “your purchase restored.” Build 2 completed processing and internal distribution.
      TestFlight automatically uses Apple's sandbox environment.
- [x] Archive and export build `1.0 (4)` with the Subscription accessibility repair
      (2026-09-10). All 139 tests across 26 suites passed first. The signed Release archive and
      App Store Connect IPA both succeeded locally. The exported app uses Apple Distribution and
      the App Store provisioning profile, carries Sign in with Apple and `beta-reports-active`,
      has `get-task-allow = false`, and embeds four privacy manifests with tracking disabled. Its
      app binary and dSYM share UUID `49F6D3A0-76BB-3874-8C1A-8977C894AF9A`. The PostHog CLI
      accepted that dSYM for `online.colorsense.ios@1.0+4` without error. Dashboard confirmation
      remains. The IPA is retained at `.build/testflight/export-1.0-4/ColorSense.ipa`. App Store
      Connect accepted the upload at 05:34 UTC, completed processing without an upload warning or
      error, marked it **Ready to Submit**, and assigned it to **ColorSense Internal**. Chris then
      installed it from TestFlight on the physical iPhone and confirmed the app's About screen
      reports **Version 1.0 (4)**. The Subscription screen also loaded and showed the expected
      current plan. Focused **What to Test** instructions are saved on the build. App Store
      Connect's Build Metadata reports **Binary State: Validated** and
      **Includes Symbols: Yes**, with the expected bundle ID, version, build number, Sign in with
      Apple entitlement, `beta-reports-active: true`, `get-task-allow: false` and no visible
      processing or privacy warning.
- [x] Archive and export the replacement privacy-validation build `1.0 (5)` (2026-09-10). All 142
      tests passed before the version-only build-number bump. The Release archive
      and local App Store Connect IPA exported successfully. The exported app uses Apple
      Distribution and the App Store provisioning profile, carries Sign in with Apple and
      `beta-reports-active`, and has `get-task-allow = false`. It embeds the app, PostHog,
      PHPLCrashReporter and PhoneNumberKit privacy manifests. The app manifest includes linked
      Purchase History and Customer Support for App Functionality, classifies Crash Data under App
      Functionality and disables tracking. The app binary and dSYM share UUID
      `323B94E5-A987-3111-A492-EC7A6300A442`. PostHog reports the same UUID under release
      `online.colorsense.ios@1.0+5`, with no failure reason. The IPA is retained at
      `.build/testflight/export-1.0-5-verified/ColorSense.ipa`. Upload and processing are confirmed
      complete in App Store Connect; build 5 is Ready to Submit and assigned to ColorSense Internal.

Verification through 2026-09-09: the physical-device feature sweep and build-1 StoreKit purchase
and persistence checks passed. Build 2's signed Release archive passed locally, its matching dSYM
is verified in PostHog, and the physical-device Restore check passed. Build 3's repaired immediate
purchase path also passed on the physical iPhone: a fresh Monthly purchase activated Pro directly
without Restore and remained Pro after force-quit and relaunch. The user explicitly parked account
deletion on 2026-09-09. The three IAP review screenshots were captured, verified and uploaded to
their matching App Store Connect records by 2026-09-10. A dedicated Free demo account was also
validated on-device. Its credentials, contact information and reviewer notes were saved only in
App Store Connect for both app-level review and Beta App Review. The external TestFlight group and
the remaining submission metadata are the next review-readiness work.

### Current go/no-go decision — 2026-09-10

- **Internal TestFlight: go.** Build `1.0 (5)` is processed, **Ready to Submit**, and assigned to
  **ColorSense Internal**, confirmed directly in App Store Connect on 2026-09-10.
  The group can accept more App Store Connect users as internal testers.
- **External TestFlight: prepare, then hold Beta App Review.** Create the external group and add the
  intended testers, but do not submit its first build for Beta App Review until the public Privacy
  Policy and Terms are final. The Support URL now points to the verified About-page contact form.
  The Subscription accessibility patch is part of the build-4 source.
- **App Store Review: hold.** Verified backend account deletion, final public legal pages,
  publication of the configured App Privacy answers and a real refund/revocation entitlement test
  remain. The support destination is complete.

---

## 2b. TestFlight external testing, and the review it needs (drafted 2026-09-09)

Internal testing is running. **External testing is a separate gate**, which is easy to miss because
internal builds skip it entirely: internal testers (up to
100, each needing a real App Store Connect role) get builds in minutes, while external testers (up
to 10,000, by email or public link) cost a **Beta App Review on every significant build**. Builds
expire after 90 days either way.

Beta App Review is a real review. It is lighter than App Store review but it is a person opening the
app, and the two things that fail it here are the two that would fail the full review.

- [x] **Create the external TestFlight group.** **ColorSense Beta** was created on 2026-09-10 and
      intentionally remains at zero testers and zero builds until the public Privacy and Support
      pages are ready for Beta App Review.
- [x] **Provide the validated demo account in Beta App Review, and say the app needs one.** The
      Free review account was created, tested and saved in the app-level App Review Information on
      2026-09-10. The same credentials, contact details and reviewer note were saved in TestFlight's
      Beta App Review Information the same day; credentials remain outside the repository. This is the
      same requirement section 3a raises for the IAP records, and it bites harder here: a reviewer
      who cannot sign in cannot reach Library, Subscription, saved palettes or anything Pro.
      **It is a mechanism, not a nicety** (noted 2026-09-09, when parking it was considered): the
      purchase path fetches a backend-issued `appAccountToken` through an *authenticated* request
      before it calls StoreKit, and the entitlement binds to a Clerk account. A signed-out reviewer
      reaches the paywall and can go no further, and In-App Purchase is precisely what they have to
      exercise to approve the app. App Store Connect has a sign-in-required field for this; leaving
      it empty while a core flow needs a login is a routine "Information Needed" rejection and a
      full round trip. The screenshots were the exception because temporary, now-removed capture
      flags reached that screen without a live account.
      **Spec: `docs/HANDOFF-demo-account.md`** — the account is **Free** and was created outside the
      repository. Onboarding's "Maybe later" exit
      means the app is usable without an account, so say that too, or the reviewer may assume the
      gate is harder than it is. The repository intentionally does not record the credentials.
- [x] **Write the Beta App Description.** A concise feature description drawn from section 5 was
      saved in TestFlight Test Information on 2026-09-10.
- [x] **Write "What to Test" for the build being sent.** Build `1.0 (4)` received focused
      Subscription accessibility, feature sweep, purchase and Restore instructions on 2026-09-10.
- [x] **Set the feedback email to `hello@colorsense.online`**, the vault's contact address in
      section 12, not a personal address. It is the same address About's "Email us" row already
      uses, so a tester who replies and a tester who taps the row reach the same inbox. Saved in
      TestFlight Test Information on 2026-09-10.
- [ ] **Confirm the privacy policy URL resolves** and covers the app. It is
      `https://colorsense.online/privacy-policy`. Checked directly on 2026-09-10: the route returns
      the same product/SEO landing content as the homepage, with no privacy policy, data practices,
      retention/deletion terms, mobile/iOS coverage or third-party disclosures. A beta reviewer
      checks the policy for what they are testing, so this is not only an App Store submission
      concern.

Two things that are already true and worth not re-deriving:

- **No purchase copy problem.** Guideline 3.1.1 applies in beta as well, and the app already routes
  every Pro tier through In-App Purchase and names no outside checkout.
- **Sign in with Apple is live**, so guideline 4.8 is satisfied for the account screen, which is
  what previously made the account beat a rejection risk on its own.

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
- [x] **Fix the immediate-purchase false negative in the client.** `reconcile` now reads through
      the injected `fetchCurrentPlan` closure and retries `/api/me` after 250 ms, 500 ms and 1 second
      before reporting that access is not active. It still refuses to finish the StoreKit
      transaction until the shared backend reports Pro or Business. Regression tests cover a stale
      Free → Free → Pro sequence and the bounded all-Free path. The full simulator suite passed
      with 138 tests on 2026-09-09.
- [x] Archive and upload TestFlight build `1.0 (3)` with the immediate-purchase retry
      (2026-09-09). The signed Release archive and App Store Connect upload both succeeded. Apple
      finished processing it, its status is **Ready to Submit**, and automatic distribution added
      it to **ColorSense Internal**. Focused purchase instructions are saved in **What to Test**.
      PostHog has the exact archive dSYM under release `online.colorsense.ios@1.0+3`, UUID
      `4FB029B4-222E-3541-B065-76BB69569F2C`, with an uploaded file and no failure reason.
- [x] Validate the repaired immediate-purchase path with a fresh Sandbox purchase in TestFlight
      build `1.0 (3)` (2026-09-09). Pro Monthly purchased successfully on a new Sandbox Apple
      Account while signed into a new Free ColorSense account. The screen changed directly to
      **Pro - Active** without Restore Purchases and remained Pro after force-quit and relaunch.
      The first attempt correctly rejected an older Apple purchase identity. App Store Connect
      showed no purchase for the new tester, revealing that TestFlight was still using the Apple
      Account signed into **Media & Purchases**. Signing out there before selecting the Sandbox
      Apple Account under **Developer** allowed the intended fresh transaction.
- [x] Confirm the In-App Purchase **tax category** for all three products. App Store Connect was
      rechecked on 2026-09-09: the parent app uses **App Store software**, and Monthly, Annual and
      Pro Pass all use **Match to parent app**.
- [x] Add final App Review notes to all three StoreKit records. The product-specific notes in
      section 3a were saved in App Store Connect on 2026-09-09.
- [x] Add the required App Review screenshot to all three StoreKit records. The three final JPEG
      captures in `docs/app-store/iap-review/` were uploaded to their matching records by
      2026-09-10. Monthly and Annual use 1320 × 2868; the Pro Pass copy uses Apple's accepted
      1242 × 2688 size because its consumable IAP form rejected the newer 6.9-inch dimensions.
      A dedicated Free demo account was created, verified through a returning sign-in, and saved in
      the app-level App Review Information on 2026-09-10.
- [x] Add a signed-transaction endpoint and core Apple purchase reconciliation to the shared
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
- [ ] Exercise a real Sandbox renewal/refund/revocation lifecycle notification and confirm it
      changes the stored grant and `GET /api/me` exactly once. Apple's successful `TEST`
      notification proves transport, JWS and bundle validation, but it carries no signed
      transaction and therefore does not prove entitlement mutation for refunds or revocations.
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

### 3a. App Review screenshot and review notes for the three IAP records (updated 2026-09-09)

The final product-specific notes were saved in each product's **App Review Information** in App
Store Connect on 2026-09-09. The three product-selected screenshots were captured and verified on
2026-09-09, then uploaded to their matching records by 2026-09-10:

- **Pro Monthly** → `docs/app-store/iap-review/pro-monthly.jpg`
- **Pro Annual** → `docs/app-store/iap-review/pro-annual.jpg`
- **Pro Pass** → `docs/app-store/iap-review/pro-pass.jpg`

Each file is a JPEG without alpha. Monthly and Annual are 1320 × 2868. Pro Pass is 1242 × 2688,
an accepted 6.5-inch iPhone size, because the consumable IAP review field rejected its original
1320 × 2868 copy. Every image shows its matching product selected and the correct purchase button.

**Use one clean capture per product, and do not use one of the six product-page shots.**
Those six are the store listing (palette, contrast, health, visualizer, SVG, schemes) and none of
them shows a purchase. Apple wants the screen where the product is actually offered. That is
**Account → Subscription** (`SubscriptionView`), which is the only surface carrying all three
products, the buy button and Restore Purchases together. The onboarding plan beat is not a
substitute: it offers monthly, annual and the trial, but never the Pro Pass.

A device or simulator capture using one of Apple's supported iPhone dimensions satisfies this
field. Monthly and Annual use the 1320 × 2868 simulator size. Pro Pass uses 1242 × 2688 because its
consumable IAP form rejected the newer 6.9-inch dimensions. Each product has a separate capture
showing its own selection and matching purchase button.

**The reviewer must sign in before any of this is reachable, and that needs saying twice.**
`AccountView` renders the Library and Account settings sections only when `clerk.user != nil`, so a
signed-out reviewer never sees a Subscription row at all. The purchase itself also requires a
session, because the client fetches a backend-issued `appAccountToken` before calling StoreKit; a
signed-out tap on the onboarding plan beat is answered with "Create or sign in to your ColorSense
account first" rather than a failure. So:

- **App Review Information at the app level has validated demo credentials.** A dedicated Free
  account passed returning sign-in and reached Account → Subscription on-device on 2026-09-10.
  Its credentials, contact information and reviewer note were saved directly in App Store Connect;
  the repository intentionally records none of the credentials.
- Repeat the path in each IAP's review notes, because reviewers read those separately.

**Saved product notes:**

- **Pro Monthly** (`online.colorsense.ios.pro.monthly`): open ColorSense and sign in with the demo
  account provided in App Review Information. Tap the account icon at the right end of the bottom
  bar, then tap Subscription. Select Pro Monthly and tap the purchase button. This is an
  auto-renewable monthly subscription with a seven-day free introductory offer for eligible new
  subscribers. The trial wording appears only when StoreKit reports that the Apple account is
  eligible. Pro unlocks SVG Recolor, one-tap WCAG contrast fixes, Palette Health remapping, Pro
  Visualizer scenes, artwork export, palette slots six through eight, and Pro export formats. The
  app verifies Apple's signed transaction with the ColorSense server before activating Pro.
  Restore Purchases is available on the same screen.
- **Pro Annual** (`online.colorsense.ios.pro.annual`): open ColorSense and sign in with the demo
  account provided in App Review Information. Tap the account icon at the right end of the bottom
  bar, then tap Subscription. Select Pro Annual and tap Choose Annual. This is an auto-renewable
  annual subscription billed yearly. It shares the ColorSense Pro subscription group with Pro
  Monthly. Pro unlocks SVG Recolor, one-tap WCAG contrast fixes, Palette Health remapping, Pro
  Visualizer scenes, artwork export, palette slots six through eight, and Pro export formats. The
  app verifies Apple's signed transaction with the ColorSense server before activating Pro.
  Restore Purchases is available on the same screen.
- **Pro Pass** (`online.colorsense.ios.pro.pass`): open ColorSense and sign in with the demo account
  provided in App Review Information. Tap the account icon at the right end of the bottom bar, then
  tap Subscription. Select Pro Pass and tap Get Pro Pass. This consumable grants 31 days of
  ColorSense Pro access and does not renew. It can be purchased again after the grant expires. Pro
  unlocks SVG Recolor, one-tap WCAG contrast fixes, Palette Health remapping, Pro Visualizer scenes,
  artwork export, palette slots six through eight, and Pro export formats. The app verifies Apple's
  signed transaction with the ColorSense server before activating Pro. Because a finished
  consumable is not included in StoreKit current entitlements, Restore Purchases restores an active
  Pro Pass from the ColorSense server.

**The temporary screenshot mode was removed after capture.** The set was produced with Debug-only
launch flags that supplied fixed review prices and a forced Free state. Those capture routes and
their fixed price data were removed from the app source on 2026-09-09; only the final JPEG assets
remain. Before the submission archive, grep the Release source and product for `iap-review` as a
final guard against capture scaffolding entering the build.
**Run for build `1.0 (5)` on 2026-09-10 and clean**: `strings` over the archived Release binary at
`.build/testflight/ColorSense-1.0-5.xcarchive` returns no `iap-review` occurrence, and the source
tree returns none either. Note the documented dev flags `-show-onboarding` and `-sample-palette` do
still appear in the binary; that is deliberate and long-standing, so do not read them as a failure
of this check.

**One sentence in the preamble is a judgment call, not a fact to copy blindly.** Explaining that the
entitlement lives on the backend is what makes the sign-in requirement look deliberate rather than
like a gate in front of a purchase, and it explains the Pro Pass restore path a reviewer would
otherwise flag. It also, unavoidably, says ColorSense has an account system spanning a website. That
is true and is not a 3.1.1 problem on its own, since nothing in the app links to or names an outside
purchase. Keep it factual, and do not extend it into anything about where Pro can otherwise be
bought.

## 4. Settle before uploading

- [x] **Decide the real version number.** The first App Store version and `MARKETING_VERSION` are
      both `1.0`; `CURRENT_PROJECT_VERSION` is `5`. Both are hand-edited in `project.yml`; nothing
      bumps them automatically.
- [x] **Increment `CURRENT_PROJECT_VERSION` on every upload**, including re-uploads of the same
      marketing version. Two independent reasons: App Store Connect rejects a reused build number,
      and PostHog binds each uploaded dSYM to the release these numbers identify, so two builds at
      one version collide and either fail the build or silently attach the wrong symbols. The next
      replacement privacy-validation build is set to `1.0 (5)` in `project.yml`.
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
- [x] **Physical-device accessibility follow-up completed (2026-09-10).** Build 4 was launched on
      the connected iPhone 17 Pro Max with Larger Accessibility Sizes enabled at the largest setting.
      The signed-in account beat kept **Continue** visible. The plan beat kept **Subscribe monthly**,
      **Restore Purchases** and **Not now** visible, and tapping **Not now** returned to the main
      palette screen. This closes the touch/exit check that simulator screenshots could not prove.
      The signed-out **Maybe later** path was separately exposed and exercised in the interactive
      simulator pass at accessibility-extra-large. The equivalent **Subscription** screen check was
      completed on the physical phone on 2026-09-09; see below.
- [x] **Subscription screen swept at accessibility sizes and in dark (2026-09-09).** Dark and the
      default size were already correct. One defect found and fixed: the hero's decorative chips
      are positioned at fixed fractions of a hero that grows with its own type, so at
      accessibility-extra-large they landed on the paragraph, covering the first character of
      "Create, refine and export". They now hide at accessibility sizes rather than moving, since no
      fixed position stays clear at every size. Simulator evidence in `.build/subscription-sweep/`.
      Confirmed on a physical iPhone 17 Pro Max: About and the paid state read correctly, and the
      free state scrolls to its purchase button, Restore Purchases and the legal links with Done
      reachable. **The free state had to be forced with the `-iap-review-monthly` capture flag**,
      because a signed-in phone renders the shorter paid layout and can never show the taller one.
      That is the same trap that hid the onboarding exit falling off the bottom of the screen, so
      reach for that flag whenever this screen is checked on a device.
      **Release bookkeeping:** the small `HeroColorConfetti` accessibility patch is included in
      build 4. Its Release archive and App Store-signed IPA passed locally on 2026-09-10, and Apple
      completed processing and assigned it to the internal group. Build 5 supersedes its symbol
      check, and the matching build-5 symbol set is verified in PostHog below.
- [x] **Re-check `PrivacyInfo.xcprivacy` in the next release build.** Build 4 passed Apple's visible
      processing checks, but questionnaire preparation on 2026-09-10 found that the manifest omitted
      the Apple purchase history retained by the server and classified crash diagnostics under
      Analytics instead of App Functionality. Build 5's exported app now contains linked Purchase
      History and Customer Support for App Functionality and the corrected crash purpose. ClerkKit,
      ClerkKitUI and Nuke ship no manifest of their own and are linked statically, so their API use
      is ours to declare; PostHog and PhoneNumberKit ship their own manifests.
      **Checked again 2026-09-10 and still accurate**, against the resolved versions rather than from
      memory: clerk-ios `1.5.1` (the version the manifest itself names, so Clerk has not moved),
      Nuke `13.2.0`, PhoneNumberKit `5.0.8`, posthog-ios `3.71.2`. Searching the SPM checkouts for
      `PrivacyInfo.xcprivacy` finds none in clerk-ios or Nuke, one in PhoneNumberKit, and two under
      posthog-ios (its own plus the bundled PHPLCrashReporter). Build 5's exported app embeds all
      four, and the app manifest declares tracking disabled. Repeat this check if any package moves.

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
| Support URL | https://colorsense.online/about |
| Marketing URL | https://colorsense.online |
| Privacy Policy URL | https://colorsense.online/privacy-policy |
| Copyright | 2026 Chrisanto Mendez |
| Contact | hello@colorsense.online |

Saved in App Store Connect on 2026-09-07: subtitle; Graphics & Design primary and Photo & Video
secondary categories; 4+ age rating; content-rights confirmation; privacy-policy URL; description;
keywords; support and marketing URLs; copyright; and manual release. Promotional text remains blank.
The app download is free and public in all 175 countries or regions. Automatic distribution on Mac
and Apple Vision Pro is off because the iPhone build has not been tested there. Six approved iPhone
screenshots were uploaded in order on 2026-09-07. Build `1.0 (3)` is processed; app-level and Beta
App Review credentials are saved. The App Privacy data types and all ten per-type answer flows were
completed in App Store Connect on 2026-09-10 but intentionally remain unpublished until the public
privacy-policy route is correct. The build-5 PostHog GeoIP check passed on 2026-09-10: a fresh
`app_opened` carried the suppression flag, no location enrichment and no stored `$ip` value.

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

**Configured in App Store Connect on 2026-09-10, not published:** Name, Email Address, Customer
Support, Other User Content, User ID and Purchases use App Functionality, are linked to identity and
are not used for tracking. Product Interaction and Other Usage Data use Analytics, are not linked
and are not used for tracking. Crash Data and Other Diagnostic Data use App Functionality, are not
linked and are not used for tracking. Every other data type is unselected. Do not publish until the
public privacy policy is fixed. The build-5 GeoIP verification below has passed.

**Data linked to the user** (through the Clerk account):
- Contact Info — email address, name. Clerk, for authentication.
- User Content — saved palettes and color names, via `/api/saved-palettes`; Customer Support — the
  name, email and message explicitly submitted through the Feedback form.
- Identifiers — user ID.
- Purchases — Apple purchase history. The verified signed transaction is retained and bound to the
  account so the server can grant and restore the correct Pro entitlement.

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

The source privacy manifest was corrected on 2026-09-10 before completing this questionnaire: it
now includes linked Purchase History and Customer Support for App Functionality and classifies
crash diagnostics as App Functionality, matching Apple's category definitions and PostHog's bundled
crash-report manifest. A production query also found IP-derived country data on every historical
iOS event and city data on some. ColorSense does not use location analytics, so the source now adds
PostHog's `$geoip_disable: true` processing property to every allowed product and crash event. These
source changes are embedded in build `1.0 (5)`, now uploaded and processed in TestFlight.
PostHog project `590983` was also changed to `anonymize_ips: true` on 2026-09-10 and read back as
enabled. The live build-5 check passed later that day: a fresh `app_opened` event carried
`$geoip_disable: true`, contained none of the checked country, city, latitude or longitude fields,
and stored no `$ip` value. Coarse Location can remain omitted from the questionnaire.

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
- [x] 6.5" iPhone — 1242 x 2688. **Not needed, closed 2026-09-09.** The line above already records
      that App Store Connect derives the 6.5" set from the uploaded 6.9" images, and nothing here
      targets that display class explicitly. It was left open as a conditional rather than a task;
      resolving it stops it reading as outstanding work on the run up to beta.

**No iPad set is required, and that is deliberate.** The app is iPhone-only for 1.0
(`TARGETED_DEVICE_FAMILY: "1"`), so App Store Connect asks for no 13" iPad captures. If iPad support
is ever added, this section gains a second full pass through all six screens. See "iPad is deferred,
and the deferral has a trigger" in CLAUDE.md.

Suggested order, leading with what the app is rather than with chrome: the palette bands; extraction
from a photo; the contrast checker on a real pairing; Palette Health with its report; the Visualizer
showing a scene; SVG Recolor.

---

## 8. After the first upload

- [x] Confirm the archive carries the production PostHog token and host, launch it, and verify
      `app_opened` reaches the dashboard. Confirmed 2026-09-10 after installing the uploaded build
      from TestFlight: PostHog received recent `app_opened` events from `posthog-ios` on iOS with
      application version `1.0` and build `4`.
- [x] Verify the dSYM appears in PostHog Symbol sets. Confirmed again 2026-09-10 for
      `online.colorsense.ios@1.0+5`; PostHog reports UUID
      `323B94E5-A987-3111-A492-EC7A6300A442`, matching the archive, with no failure reason.
- [ ] Trigger one controlled crash in an internal build, relaunch so the stored report uploads, and
      verify `$exception` arrives symbolicated, both reliability tiles move, and the Discord
      issue-created alert fires. **Remove the crash trigger before external distribution.**
- [ ] Read Apple's server-side privacy-manifest report and resolve any warning. That report is the
      authoritative aggregation, not our copy of it. Build 4 is **Validated** and App Store Connect
      displays no processing or privacy warning in Test Information or Build Metadata, but those
      pages do not expose the aggregated report itself.
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

**1. Fix account deletion (blocker).** Work from `docs/replit-account-deletion-handoff.md`, which
carries the evidence, the per-table decisions and the acceptance criteria. In summary: add a
*verified* Clerk `user.deleted` webhook to the
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
      depends on both. **The implementation brief is `docs/replit-account-deletion-handoff.md`**
      (written 2026-09-09), which adds two findings the audit did not have: the cascade reaches only
      three tables, and `requireAuth`/`optionalAuth` recreate the user row lazily, so the webhook
      alone leaves a resurrection race that can also fire a Loops welcome email at somebody who just
      deleted their account.
- [ ] **Finalise the mobile-aware Privacy Policy and Terms of Service.** Direct browser verification
      on 2026-09-10 confirmed that `https://colorsense.online/privacy-policy` now serves a real policy
      covering the website, Chrome extension and iOS app. Before it is final, change its displayed
      revision date to the actual deployment date and replace the conditional iOS-purchase sentence
      with the shipping StoreKit behavior. `https://colorsense.online/terms` still serves the old
      May 7 website-only Terms of Use and does not cover accounts, sync or App Store billing. Use
      `docs/replit-website-legal-handoff.md` for the remaining work. Account-deletion wording must
      change only after the backend deletion lifecycle is proved end to end.
- [x] **Point the App Store Support URL to the existing About-page contact surface** (2026-09-10).
      `https://colorsense.online/about` was checked directly and provides both
      `hello@colorsense.online` and a contact form. App Store Connect version 1.0 now saves that URL
      as Support URL; the Marketing URL remains `https://colorsense.online`.
- [x] **Add "Leave a review" to the About screen** (2026-09-09). The App Store record exists, so the
      condition it was waiting on is met. It is the third row in About's "Reach us" group, ordered
      after Send feedback and Email us so the three run from the most private way to say something
      to the most public. It opens
      `https://apps.apple.com/app/id6809134374?action=write-review`, the app's real Apple ID.
      **One thing to expect before release:** that URL resolves only once the listing is public, so
      a TestFlight tester who taps it now reaches a page the App Store cannot show. It fixes itself
      at release and needs no code change, but it will look like a bug if a tester reports it.
- [ ] **Read the device split before reopening iPad** (raised 2026-09-09). The case for an iPad app
      rests on the claim that much of the target market works on iPad, and nothing in the repo or
      the vault tests it. Two reads settle it: colorsense.online's own analytics, which cover the
      same audience today, and App Store Connect after launch, since an iPhone-only app still
      installs and runs on iPad in a scaled window and so reports iPad installs by itself. If either
      shows a meaningful share, a real regular-size-class layout is a 1.1 update rather than
      anything that blocks this submission. Does **not** block release.
- [x] **Record the iPad deferral in the vault** (2026-09-09). Section 22 now carries it as a fourth
      fact that matters beyond the code: iPhone-only for 1.0, portrait-locked, reopened only on a
      measured device split, and a redesign rather than a resize if it is.
- [x] **Reconcile the vault with iOS scope** (2026-09-06). Section 22 now records the seven tools,
      Schemes landing, Website Analyzer deferred, Brand Kit waiting on demand, the current Pro
      surfaces, and StoreKit as a release requirement.
- [x] **Capture the App Store screenshots** at 6.9" (1320 x 2868), completed 2026-09-06.
      Six native screenshots and a review gallery are in `docs/app-store/`. A photo extraction
      image remains an optional addition using an approved sample photo.
- [x] **Reconcile the trial with the vault** (2026-09-06). Section 3 now records the agreed 7-day
      iOS introductory offer on Monthly, explicitly awaiting StoreKit configuration and eligibility checks.
