# Claude handoff: finish ColorSense beta and App Review preparation

**Date:** 2026-09-11 (Macau)
**Repository:** `/Users/chrisantomendez/Developer/ColorSense-iOS`
**Current release:** `1.0 (6)`

## Start here

Do not repeat the account-deletion implementation or legal-page work. Read:

1. `CLAUDE.md`
2. `docs/HANDOFF.md`
3. `docs/APP-STORE-SUBMISSION.md`
4. `docs/PRIVACY-AUDIT.md`

Preserve `/api/saved-palettes` and `/api/me` response contracts. Never put review credentials,
Apple IDs, Clerk IDs, tokens or private keys in the repository.

## Current state

- Build `1.0 (6)` was archived and uploaded successfully on 2026-09-11.
- App Store Connect accepted the upload and began processing it.
- Build 6 was submitted for the first external TestFlight Beta App Review and currently shows
  **Waiting for Review**.
- The external group is intended for the owner's brother, whose iPhone/Apple Account has not used
  ColorSense. After approval, use that device for the Hide My Email acceptance test.
- The build-6 archive is
  `.build/testflight/ColorSense-1.0-6.xcarchive`.
- App and dSYM UUID match:
  `3AB2578C-A17B-349B-AD08-5D9D4E27D661`.
- All 145 tests passed with zero failures before archiving.
- `PrivacyInfo.xcprivacy` is present in the app archive. The PostHog, PHPLCrashReporter and
  PhoneNumberKit manifests are also embedded.
- Build 6 includes the server-owned account-deletion client, corrected 31-day Pro Pass wording,
  and the redesigned deletion confirmation.

## Account deletion is complete

Do not reopen this unless new evidence contradicts it.

- Production iPhone test passed deletion, automatic sign-out, force-quit/relaunch and continued
  signed-out Extractor/WCAG use.
- Google reauthentication created an empty account; deleted saved data did not return.
- Replit controlled backend checks passed 9/9:
  - forced Clerk failure returns `502`;
  - retry returns `200 { deleted: true }`;
  - repeated local deletion is idempotent;
  - exactly one tombstone existed during the test;
  - a tombstoned stale identity cannot recreate its local account;
  - synthetic rows were cleaned up (0 test users, 0 test tombstones).
- The original deleted production Clerk ID is unavailable. Do not substitute the subsequently
  recreated Google identity's ID.
- The September 11 Privacy Policy and Terms of Service are live and verified. Both name website
  and in-app iOS deletion controls; Terms retains the separate subscription-cancellation warning.

## Next task: App Store Privacy questionnaire

Use the final recommendations in `docs/PRIVACY-AUDIT.md`. The intended declarations are:

| Data type | Linked | Tracking | Purpose | Optional context |
|---|---:|---:|---|---|
| Email Address | Yes | No | App Functionality | Account optional |
| Name | Yes | No | App Functionality | Account optional |
| User ID | Yes | No | App Functionality | Account optional |
| Other User Content | Yes | No | App Functionality | Saved palettes |
| Customer Support | Yes | No | App Functionality | Feedback form |
| Purchase History | Yes | No | App Functionality | Pro entitlement |
| Product Interaction | No | No | Analytics | User can opt out |
| Other Usage Data | No | No | Analytics | User can opt out |
| Crash Data | No | No | App Functionality | Same diagnostics opt-out |
| Other Diagnostic Data | No | No | App Functionality | Same diagnostics opt-out |

Do **not** declare Photos or Coarse Location as collected. Photos remain on device. PostHog events
carry `$geoip_disable: true`, IP anonymization was verified, and tracking is disabled.

Before saving App Store Connect answers, compare every choice with the archive manifest and the
final audit. Record what was saved and any App Store Connect wording that differs from the table.
Do not guess if Apple's UI presents a materially different choice.

## Remaining release blockers, in order

### 1. Sign in with Apple — Hide My Email

Wait for TestFlight Beta App Review approval. The brother's device must confirm ColorSense is not
already listed under Settings → Apple Account → Sign in with Apple. Then:

1. Install build 6 from the emailed external TestFlight invitation.
2. Choose Continue with Apple and **Hide My Email**.
3. Complete account creation.
4. Save a palette and confirm it appears in Library.
5. Confirm ColorSense email reaches the real inbox through Apple's private relay address.
6. Sign out, sign back in with Apple, and confirm the same palette/account returns.

Do not request or record the brother's Apple password, verification code or relay address.

### 2. StoreKit refund/revocation lifecycle

Exercise a real Sandbox renewal/refund/revocation notification and prove it updates the stored
grant and `GET /api/me` exactly once. Apple's prior `TEST` notification passed transport and JWS
verification but contained no signed transaction, so it did not prove entitlement mutation.
Monthly, Annual, Pro Pass, immediate activation, expiry, restore, ownership protection and Pro Pass
idempotency have already passed; do not repeat them unless needed to set up the lifecycle test.

### 3. Build-6 processing checks

Mostly **done** as of 2026-09-11, verified through the App Store Connect API rather than the UI:

- build 6 is `VALID`;
- it is assigned to `ColorSense Internal` **and** the external `Apple Sign-In Test` group;
- its Beta App Review submission reads `WAITING_FOR_REVIEW`;
- UUID `3AB2578C-A17B-349B-AD08-5D9D4E27D661` is in PostHog under
  `online.colorsense.ios@1.0+6`, `has_uploaded_file: true`, no failure reason. The archive's own
  binary and dSYM were re-read with `dwarfdump` and both carry that same UUID, so the chain from
  source to symbol set is proved end to end. **The non-fatal "release not found" warning the archive
  phase emitted was a false alarm** — the upload did succeed.

Still open here: Apple's aggregated privacy-manifest report is UI-only and not exposed by the API,
so that one warning check has to be read in App Store Connect by eye. And install build 6 from
TestFlight to confirm About reports `Version 1.0 (6)`.

### 4. Final App Review preparation

Recheck the final metadata, screenshots, Support URL, age rating, App Review notes and demo account.
Attach Monthly, Annual and Pro Pass to the same submission only when the submitted build is
selected. Do not press the final App Store **Submit for Review** until Hide My Email, StoreKit
lifecycle and privacy answers are complete.

Verified through the API on 2026-09-11: Support URL `colorsense.online/about`, marketing URL set,
demo account and contact details and review notes all present, age rating `FOUR_PLUS` with no
non-default declarations, six `APP_IPHONE_67` screenshots all `COMPLETE`, and no build attached to
version `1.0` yet.

**One blocker was found and fixed in that pass.** The consumable Pro Pass sat at
`MISSING_METADATA` because it carried **no territory availability record at all**, while Monthly and
Annual each had one covering 175 territories. Everything else on the Pass was already present. Its
availability was created on 2026-09-11 by mirroring Monthly exactly (same 175 territories, same
`availableInNewTerritories: false`), and all three products now read `READY_TO_SUBMIT`. Note the
earlier 2026-09-09 recheck recorded in `docs/HANDOFF.md` claimed all three were already available in
175 countries; that was true of the subscriptions only. Also note the Pass's review screenshot is
1242 x 2688 against the subscriptions' 1320 x 2868 — accepted by Apple, cosmetically inconsistent.

### 5. Build 7 (decided 2026-09-11)

**Build 7 is needed, and is no longer a question — only its timing is.** Two things are queued for
it, and neither is in build 6:

1. **The destructive delete button renders coral, not red.** `DeleteAccountView` asked for red with
   `.buttonStyle(.primaryAction)` plus `.tint(.red)`, but `PrimaryActionButtonStyle` paints
   `BrandColor.coral` itself and never reads the environment tint, so the tint did nothing. The
   style now takes a colour and the screen uses `.buttonStyle(.primaryAction(tint: .red))`. Fixed in
   the working tree on 2026-09-11, after build 6 was archived at 11:04, so **build 6 ships the
   coral button**. Cosmetic rather than functional: the confirmation alert still carries a proper
   destructive action and the rest of that screen is already red.
2. **The controlled PostHog crash/symbolication check**, previously item 5. It needs a temporary
   internal-only crash trigger, verification that the symbolicated `$exception` arrives after
   relaunch, and **removal of that trigger before any external or App Store distribution**.

**Do not cut build 7 yet.** Uploading a new build means a fresh Beta App Review for the external
group, which would delay the Hide My Email test that build 6 is already queued for. Let build 6
clear review, run the Hide My Email and StoreKit lifecycle tests on it, then batch both items above
into build 7 before App Store submission. Bump `CURRENT_PROJECT_VERSION` to `7` when that happens;
it is still `6` today.

## Non-blockers

- iPad remains intentionally deferred for 1.0 (`TARGETED_DEVICE_FAMILY = 1`).
- Device-split analysis is a post-launch input for a possible 1.1 iPad redesign.
- Sparse weekly analytics retention is expected and does not block release.

## Working-tree caution

The build-6 implementation and documentation were **committed on 2026-09-11**, together with the
delete-button fix and the App Store Connect API tooling, so the earlier warning about an uncommitted
worktree no longer applies. The standing rules still do: inspect `git status` and `git diff --check`
before any commit, do not reset or discard existing changes, and increment
`CURRENT_PROJECT_VERSION` above `6` before any future upload.

