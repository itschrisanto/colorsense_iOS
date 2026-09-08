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

1. **Validate the repaired immediate-purchase path with a fresh Sandbox purchase.** The client fix
   was implemented on 2026-09-09 after the code review described below. Nothing in
   `ProStore` branches on Annual, so there is no Annual-specific fault to find, and the shape of
   the failure matches `reconcile(_:transaction:)` requiring its **second** call, `GET /api/me`, to
   already report a paid plan, once, with no retry. `reconcile` now uses the injected plan reader
   and retries after 250 ms, 500 ms and 1 second. It still leaves the Apple transaction unfinished
   unless `/api/me` confirms Pro or Business.

   Acceptance run:

   - On the next Annual Sandbox purchase, confirm that Apple success proceeds directly to active
     Pro without requiring Restore Purchases. If it still fails, capture the reconcile call's status
     and body, then the status and `plan` of the `/api/me` calls that follow, with the wall-clock gaps.
     Share statuses and identifiers only; never paste a complete signed JWS or any secret.
   - The implementation and unit regression tests are complete. The stale Free → Free → Pro test
     confirms the retry succeeds, while the all-Free test confirms the retry is bounded at four
     total reads and never grants access. The full 138-test simulator suite passed.
   - **If the capture disproves the hypothesis**, fall back to the original comparison: verified JWS
     status, product ID, app-account token, transaction ID and backend response status for the
     failing Annual submission against the successful Restore one.

   TestFlight build `1.0 (3)` containing the fix was archived and uploaded successfully on
   2026-09-09. App Store Connect finished processing it, marked it **Ready to Submit**, and added it
   to **ColorSense Internal**. Focused **What to Test** instructions are saved. PostHog has its
   archived dSYM UUID `4FB029B4-222E-3541-B065-76BB69569F2C` under
   `online.colorsense.ios@1.0+3` with no failure. The remaining step is physical-device acceptance.
2. Test cancellation/expiration and server-notification behavior for Annual if the Sandbox timing
   permits. Monthly lifecycle behavior already passed.
3. The In-App Purchase tax category is confirmed: all three records match the parent app's
   **App Store software** category.
4. Final review notes are saved for all three StoreKit records. Capture and upload the three
   product-selected App Review screenshots described in `docs/APP-STORE-SUBMISSION.md` section 3a.
5. Turn the purchase gate on for the final Release configuration only after every remaining test
   passes, then run the full test suite and create a fresh archive with an incremented build number.

### Client-side reading of the Annual discrepancy (diagnosis applied 2026-09-09)

This was the code-based diagnosis that led to the bounded retry. The next Sandbox run still has to
confirm it against Apple's real purchase callback.

**Nothing in the client branches on Annual.** `ProStore.purchase(_:)` and `reconcile(_:transaction:)`
handle Monthly and Annual through one identical path; the only product-dependent checks are the
product ID match, the configured-kind check, and the `appAccountToken` equality test, and all three
produce their own specific messages rather than a generic one. So there is no Annual-specific client
bug to find. Whatever happened, Annual lost a race that Monthly and the Pass happened to win.

**The likely branch was the second network call inside `reconcile`.** After the backend had already
confirmed the grant, `reconcile` makes a *separate* `GET /api/me` call and requires it to report
`pro` or `business` before finishing the transaction. If that read does not yet see the write the
previous call just made, the purchase is reported to the reader as:

> "The purchase was verified, but Pro access is not active yet. Try Restore Purchases shortly."

That is a failure message shown immediately after money has been taken, and it names Restore
Purchases, which is exactly what then worked. The reported symptom fits this branch closely.

Three things make it more likely than a verification fault:

- **There was one read and no retry.** A single lagging response was enough to produce the error.
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

**Applied fix.** The client retries the `/api/me` read after 250 ms, 500 ms and 1 second before
declaring failure, and still does not finish the transaction until access is confirmed. It does not
simply trust the reconcile response: the second read prevents a stale or wrongly combined plan from
finishing a transaction before iOS and the website actually have access.

**Applied testability change.** Both `restore()` and `reconcile` now read the plan through the
injected `fetchCurrentPlan` closure. The regression tests exercise eventual paid access and the
bounded failure path without waiting in real time.

## Product and service references

- App: **ColorSense: Palette Studio**, Apple ID `6809134374`
- Bundle ID: `online.colorsense.ios`
- Monthly: `online.colorsense.ios.pro.monthly`, Apple ID `6809206814`, `$5`
- Annual: `online.colorsense.ios.pro.annual`, Apple ID `6809207967`, `$39`
- Pro Pass: `online.colorsense.ios.pro.pass`, Apple ID `6809208412`, `$9`, consumable
- Subscription group: **ColorSense Pro**, ID `22363784`
- Server notification URL: `https://colorsense.online/api/webhooks/apple/app-store`

`ColorSense.xcodeproj` is generated by XcodeGen. The user-requested Subscription redesign is
implemented; its original brief remains in `docs/SUBSCRIPTION-REDESIGN-BRIEF.md`.
