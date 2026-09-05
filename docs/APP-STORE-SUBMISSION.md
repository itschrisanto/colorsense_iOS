# ColorSense iOS — App Store submission

The reference for getting this app into review, and the record of why each decision was made.
Written 2026-09-05, when everything that can be done without an Apple Developer account is done.

**Facts here that belong to the brand — pricing, positioning, handles, contact — are owned by the
vault** (`Claude Skill.md`), not by this file. Where copy is drafted below it is drafted *from* the
vault; if the two ever disagree, the vault wins and this file is stale.

---

## 1. Where things stand

**The backend is done and in production.** The Express API at `colorsense.online/api`, Postgres
through Drizzle, Clerk auth on the production instance, and PostHog analytics with error tracking.
iOS is a client of the same stack the web app uses, verified end to end on a physical iPhone: email
and Google sign-in, saving a palette to the account, and the palette appearing on colorsense.online.

**The app is built.** Six tools ship: Extractor, Contrast, Health, SVG Recolor, Visualizer and
Library, plus onboarding, the palette workspace, Account, About and Feedback. 113 tests pass.

**Nothing on Apple's side exists**, and that single gap is the whole remaining gate. See section 2.

---

## 2. Blocked on the Apple Developer Program ($99/yr)

Nothing below can start until enrolment completes. Enrol as an **Individual** for a fast turnaround,
or as an **Organization** if the listing must read "ColorSense" rather than a personal legal name —
that needs a D-U-N-S number and roughly a week, and **the type cannot be changed later without
re-enrolling**, so decide before paying.

- [ ] Register the App ID `online.colorsense.ios`
- [ ] Provision **Sign in with Apple** for that App ID, and enable the entitlement for Debug too.
      It is Release-only today because Apple refuses this capability to Personal Teams.
- [ ] Register the Team ID and bundle ID as a **Clerk Native Application**, and enable Apple for
      sign-up and sign-in on the production Clerk instance. Guideline **4.8** requires Sign in with
      Apple wherever a third-party sign-in is offered, and the account screen offers Google today,
      so this is a rejection on its own until done.
- [ ] Create the App Store Connect record
- [ ] Create the StoreKit products (section 3)
- [ ] Distribution certificate, then `xcodebuild archive`

**Release does not compile today.** Measured 2026-09-05: it fails signing because the provisioning
profile has no Sign in with Apple capability. That is expected on a Personal Team and resolves with
enrolment. To exercise a Release build before then, `CODE_SIGNING_ALLOWED=NO` works.

---

## 3. StoreKit, and why it gates submission

`Services/ProStore.swift` is the seam; every screen offering Pro already calls through it, so wiring
is writing one conforming type rather than reworking onboarding. The file carries the step-by-step
checklist.

- [ ] **Pro Monthly $5/mo and Pro Annual $39/yr in ONE subscription group.** Two groups means a
      reader cannot switch without double-paying.
- [ ] **Pro Pass $9 is a consumable, not a subscription**, and must not go in that group. It is a
      one-month, one-time purchase that can be bought again once it lapses, which a non-consumable
      cannot. Getting this wrong is a wrong product in App Store Connect, replaced rather than
      edited. `ProProduct.kind` records it.
- [ ] Attach the trial as an **introductory offer on the monthly product**. Whatever length is
      configured must match the onboarding plan beat's copy, and **the trial is still not in the
      vault** — that is a pricing decision the vault needs, not an Apple one.
- [ ] Write `StoreKitProStore`, point `ProStoreRegistry.current` at it.
- [ ] **Add a Restore Purchases control.** App Review requires one for auto-renewable
      subscriptions. There is deliberately no dead button for it today.

**The onboarding plan beat stays in the flow** (decided 2026-09-05). It offers a trial and a
subscription and cannot purchase anything, which guideline **3.1.1** makes a rejection by itself, so
**this app cannot be submitted until StoreKit is wired.** Hiding it was the alternative and was
declined; `advanceFromAccountAsk()` still routes past the beat, so hiding remains close to a
one-line change if that call is ever reversed.

**Pro is sold through Lemon Squeezy on the web.** On iOS the same tiers must go through In-App
Purchase. Never link to a Lemon Squeezy checkout from inside the app, and never add copy pointing at
where to buy on the web — that is the same rule that already removed "Pro is available at
colorsense.online" and that keeps the About screen's Support row out.

---

## 4. Settle before uploading

- [ ] **Decide the real version number.** `MARKETING_VERSION` is still `0.1.0` and reads as a
      prototype. `CURRENT_PROJECT_VERSION` is `1`. Both are hand-edited in `project.yml`; nothing
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
- [ ] **Follow-up: the account ask now scrolls on smaller screens.** The blocker is gone and nothing
      is unreachable, but the hero is no longer guaranteed to fit, so the last line of the paragraph
      can sit below the fold. Sizing the composition down until it fits without scrolling is the
      finishing pass. Do not solve it with `ViewThatFits` or by measuring the stack's own height:
      both were tried and both fail for reasons recorded in `OnboardingFlowView`.
- [ ] **Sweep the rest of the flow on an SE.** Only the account ask was checked. `mood` and `plan`
      carry more content than the beats around them and are the next most likely to overflow.
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
| Name | ColorSense |
| Subtitle | Image color palette generator |
| Bundle ID | `online.colorsense.ios` |
| Primary category | Graphics & Design |
| Secondary category | Photo & Video |
| Age rating | 4+ |
| Support URL | https://colorsense.online |
| Marketing URL | https://colorsense.online |
| Privacy Policy URL | https://colorsense.online/privacy-policy |
| Copyright | ColorSense |
| Contact | hello@colorsense.online |

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

- [ ] 6.9" iPhone — 1320 x 2868
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

## 8c. Deferred until Apple Developer access (agreed with Replit, 2026-09-05)

**Do not act on any of this now.** The privacy work below is deliberately parked until the app is
otherwise ready to submit and the developer account exists. `docs/PRIVACY-AUDIT.md` is the
**baseline**, not the final word: it audited a development build, and the audit is to be re-run
against the final archived Release build and its dependency lockfile.

**1. Fix account deletion (blocker).** Add a *verified* Clerk `user.deleted` webhook to the
backend: match the Clerk user to the local Postgres user, delete that row, and confirm the existing
`saved_palettes.user_id` cascade removes the palettes. Webhook retries must be idempotent, and
unsigned or invalid requests must be rejected. Test deletion from **both** the iOS app and the
website, and confirm the Clerk identity, the local profile, the saved palettes and every other
account-linked row are actually gone. **Preserve the `/api/saved-palettes` and `/api/me` response
contracts.** Publish no deletion claim until this is proved end to end.

**2. Sign in with Apple, if it ships.** Provision the capability, confirm the production bundle id,
entitlements, certificate and profile, configure the Clerk integration and callback, then test new
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
      Parked until the Replit side is being touched anyway.
- [ ] **Add "Leave a review" to the About screen** the day the App Store record exists, with the
      real App ID. It is deliberately absent because it would currently go nowhere.
- [ ] **Reconcile the vault with what iOS actually is** (parked 2026-09-05, not started). It has
      not caught up with: seven tools shipping, Website Color Analyzer deferred, Brand Kit Creator
      waiting on demand rather than on a slot in the port order, and the Schemes tool landing. This
      matters beyond tidiness — the onboarding Pro pitch promised brand kits and AI harmonies
      because it was written from the web's feature list, and the vault is the source those lists
      come from.
- [ ] **Capture the App Store screenshots** at 6.9" (1320 x 2868), per section 7. Can be done
      without the developer account, from a simulator.
- [ ] **Reconcile the trial with the vault.** Section 3 lists Pro Monthly, Pro Annual and the Pro
      Pass with no trial of any length, and the app shows one.
