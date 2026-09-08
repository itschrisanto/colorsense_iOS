# StoreKit physical-device checkpoint — 2026-09-07

This is the restart point for the App Store purchase work. Read this before continuing StoreKit
testing. No passwords, private keys, signed transactions or bearer tokens are recorded here.

## Exact state when testing stopped

- The development build is installed on the paired iPhone 17 Pro Max and StoreKit purchases are
  enabled through the gitignored `Config/Secrets.xcconfig`.
- The iOS app is signed into the **second/free ColorSense account** whose email begins
  `mod.chrisanto.mendez`. Its Subscription screen correctly shows **Free**.
- The iPhone's current Sandbox Apple Account is the tester whose email begins
  `mod.chrisanto.mendez`. Apple billing identity and ColorSense/Clerk identity are separate systems,
  even when their email strings happen to match.
- The active Annual Sandbox transaction is owned by the **first ColorSense account**, whose email
  begins `chrismendez13` and uses iCloud. Do not attempt to move that entitlement to the second
  ColorSense account.
- The final action before stopping was a cross-account Restore Purchases attempt. The backend
  returned HTTP `403`, the second account remained Free, and the app displayed:
  `This App Store purchase is already linked to another ColorSense account.`
- Xcode's most recent Debug build includes the final `403`/`409` ownership-message mapping. A quiet
  Simulator Debug build and `git diff --check` both passed after that change.

## Completed StoreKit acceptance evidence

### Production integration

- The separate App Store Connect In-App Purchase key was created, downloaded once and installed in
  Replit Secrets. Do not put the `.p8` file or its contents in this repository.
- Both Production and Sandbox App Store Server Notifications use Version 2 and point to
  `https://colorsense.online/api/webhooks/apple/app-store`.
- The account-token and transaction routes reject unauthenticated requests with `401`; the public
  notification route rejects an empty unsigned payload with `400 Invalid signed payload`.
- Paid Apps Agreement, bank account, U.S. tax forms and EU DSA trader compliance are complete.

### Monthly subscription

- A fresh Free ColorSense account bought Monthly in Apple Sandbox with the seven-day introductory
  offer.
- Apple confirmation succeeded, `/api/me` changed to Pro, and Pro remained after force quit and
  relaunch.
- Restore Purchases succeeded on the owning ColorSense account without creating additional access.
- Replit confirmed two Sandbox renewal periods with valid ownership binding. The final period
  expired at 2026-09-07 07:56 Macau time; both web and iOS then returned to Free. Renewal,
  persistence and expiration therefore passed.

### Annual subscription

- Annual was purchased in Sandbox for the first/iCloud ColorSense account.
- The immediate `Product.purchase()` path displayed a local App Store verification error, but a
  subsequent Restore Purchases reconciled the same transaction and activated Pro. Annual product
  and backend activation passed; the immediate callback discrepancy still needs diagnosis before
  release.
- Restore on the owning account succeeded and remained Pro.
- While Annual was active, Restore on the second ColorSense account returned `403`, left that
  account Free, and showed the explicit ownership message. Cross-account protection passed.

## Pro Pass — completed on device

A second, clean Sandbox Apple Account was created with the controlled Gmail `+pass` subaddress so
the consumable test was isolated from the Annual history. The iOS app remained signed into the
second/free ColorSense account.

- The Apple sheet showed **ColorSense Pro Pass**, **Sandbox**, `$9.00`, **One-time charge**, no real
  charge and the new `+pass` tester.
- Apple confirmation succeeded and the ColorSense account changed from Free to Pro after backend
  verification.
- Pro remained after force quit and relaunch, proving `/api/me` persistence.
- Finished consumables are absent from StoreKit current entitlements. The client was corrected to
  check the authenticated backend entitlement when StoreKit finds no active subscription. The
  updated build then returned **Your purchase was restored** and remained Pro on the owning
  ColorSense account.
- Replit confirmed the production record is Sandbox product
  `online.colorsense.ios.pro.pass`, bound to the intended Clerk user, with exactly one transaction
  and one original transaction ID (masked transaction `2000…7074`). The verified purchase was
  2026-09-07 05:15:26 UTC / 13:15:26 Macau and expiration is exactly 31 days later at
  2026-10-08 05:15:26 UTC / 13:15:26 Macau. Duplicate authenticated submissions both returned
  `200`, created one row and did not extend expiration. `/api/me` resolves the account to Pro.
- Apple notification requests around this purchase initially returned `400`, including one before
  the authenticated transaction submission and another later attempt. Replit corrected and
  deployed the Version 2 handler. Apple's Sandbox Request a Test Notification and Get Test
  Notification Status then reported `SUCCESS`: a verified `TEST` notification for
  `online.colorsense.ios` received HTTP `200` at 2026-09-07 05:55:18 UTC, created one notification
  event and left transaction, pending-transaction and active-entitlement counts unchanged. The
  notification transport and verification blocker is closed.

## Remaining StoreKit work after Pro Pass

1. Diagnose the Annual immediate-purchase verification discrepancy. Replit should inspect the
   Annual transaction submission and compare it with the successful Restore submission: verified
   JWS status, product ID, app-account token, transaction ID and backend response status. Share
   statuses and identifiers only; never paste the complete signed JWS or secrets.
2. Test cancellation/expiration and server-notification behavior for Annual if the Sandbox timing
   permits. Monthly lifecycle behavior already passed.
3. Confirm the In-App Purchase tax category for Monthly, Annual and Pro Pass.
4. Add an App Review screenshot and concise review notes to every StoreKit record.
5. Turn the purchase gate on for the final Release configuration only after every remaining test
   passes, then run the full test suite and create a fresh archive with an incremented build number.

### Client-side reading of the Annual discrepancy (added 2026-09-09)

Read from the code rather than reproduced, so treat this as the hypothesis the next Sandbox run
should test rather than a settled cause. It does narrow where to look, and it argues the item above
is **mis-framed**.

**Nothing in the client branches on Annual.** `ProStore.purchase(_:)` and `reconcile(_:transaction:)`
handle Monthly and Annual through one identical path; the only product-dependent checks are the
product ID match, the configured-kind check, and the `appAccountToken` equality test, and all three
produce their own specific messages rather than a generic one. So there is no Annual-specific client
bug to find. Whatever happened, Annual lost a race that Monthly and the Pass happened to win.

**The likely branch is the second network call inside `reconcile`.** After the backend has already
confirmed the grant, `reconcile` makes a *separate* `GET /api/me` call and requires it to report
`pro` or `business` before finishing the transaction. If that read does not yet see the write the
previous call just made, the purchase is reported to the reader as:

> "The purchase was verified, but Pro access is not active yet. Try Restore Purchases shortly."

That is a failure message shown immediately after money has been taken, and it names Restore
Purchases, which is exactly what then worked. The reported symptom fits this branch closely.

Three things make it more likely than a verification fault:

- **There is one read and no retry.** A single lagging response is enough to produce the error.
- **The two calls need not see the same database state.** `/api/me` recomputes the plan at read time
  through `effectivePlan(...)` and can also run `reconcileEntitlement`; nothing guarantees the
  just-committed grant is visible to it if the read lands on a different pooled connection.
- **The transaction is deliberately not finished in this branch**, which is correct and is why the
  entitlement survived: the launch-time retry and Restore both pick it up afterwards. The defect is
  the message and the false negative, not lost access.

**What to capture on the next Annual Sandbox purchase**, which decides it in one run: the HTTP
status and body of the reconcile call, then the status and `plan` value of the `/api/me` call that
follows it, with the wall-clock gap between them. If reconcile returned a paid plan and `/api/me`
returned `free` milliseconds later, this is the cause and the fix is client-side.

**Fix shape, if confirmed.** Retry the `/api/me` read two or three times with a short backoff before
declaring failure, and keep not finishing the transaction until access is confirmed. Do not simply
trust the reconcile response instead: the second read exists so a stale or wrongly combined plan
cannot finish a transaction before iOS and the website actually have access, which is a good reason.

**One testability note worth fixing in the same pass.** `restore()` reads the plan through the
injected `fetchCurrentPlan` closure, but `reconcile` calls `SavedPaletteService.currentPlan()`
directly. That single inconsistency is why this branch cannot be exercised by a unit test today,
and it is the reason a regression test does not already cover it. Routing `reconcile` through the
same injected closure would make the retry behavior pinnable the way the restore paths already are.

## Product and service references

- App: **ColorSense: Palette Studio**, Apple ID `6809134374`
- Bundle ID: `online.colorsense.ios`
- Monthly: `online.colorsense.ios.pro.monthly`, Apple ID `6809206814`, `$5`
- Annual: `online.colorsense.ios.pro.annual`, Apple ID `6809207967`, `$39`
- Pro Pass: `online.colorsense.ios.pro.pass`, Apple ID `6809208412`, `$9`, consumable
- Subscription group: **ColorSense Pro**, ID `22363784`
- Server notification URL: `https://colorsense.online/api/webhooks/apple/app-store`

The repository has a large pre-existing uncommitted release-preparation working tree. Do not reset,
clean or discard it. `ColorSense.xcodeproj` is generated by XcodeGen and is intentionally untracked.

After the StoreKit notification blocker is resolved, implement the user-requested Subscription page
redesign from `docs/SUBSCRIPTION-REDESIGN-BRIEF.md`.
