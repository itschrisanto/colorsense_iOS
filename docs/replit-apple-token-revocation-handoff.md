# Replit handoff: verify and close Sign in with Apple token revocation

**Date:** 2026-09-12 (Macau)  
**Priority:** App Store submission blocker  
**Owner:** Replit-managed ColorSense backend and production Clerk tenant

> **Completed automatic path, 2026-09-12.** Replit deployed nonce-bound Apple reauthorization and
> revocation, and iOS commit `15abba0` implemented the native contract. A purpose-made production
> Apple account completed deletion on a physical iPhone; the app returned to Sign In only after
> exact backend success, and ColorSense was absent from Settings > Sign in with Apple immediately
> afterward. Verdict: **programmatic Apple revocation verified — submission item closed.** The
> TN3194 manual fallback remains implemented; its forced-failure UI path is a separate outstanding
> acceptance check.

## Objective

Determine whether the existing authenticated `DELETE /api/account` flow revokes the Apple
authorization when the deleted Clerk identity was created with Sign in with Apple. If it does not,
implement the smallest secure server-side fix and prove it end to end.

Do not return a proposed plan or infer that deleting the Clerk user is sufficient. Inspect the
actual production integration and report evidence.

Apple's current requirements and implementation guidance:

- Apps supporting Sign in with Apple should revoke user tokens when an account is deleted:
  <https://developer.apple.com/support/offering-account-deletion-in-your-app>
- The programmatic endpoint is `POST https://appleid.apple.com/auth/revoke`; it requires the exact
  client identifier used for authorization, a signed client-secret JWT, and a valid Apple refresh
  or access token:
  <https://developer.apple.com/documentation/signinwithapplerestapi/revoke-tokens>
- If no Apple refresh token, access token or authorization code is available, account deletion must
  still succeed. Apple's fallback is to delete the account data, direct the user to revoke access
  manually, and handle the resulting revoked credential state:
  <https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple>

## Existing production contract — preserve it

The deployed backend owns account deletion:

1. iOS calls authenticated `DELETE /api/account`.
2. The backend deletes and tombstones ColorSense data under its existing PostgreSQL advisory lock.
3. It then deletes the Clerk identity.
4. It returns `200 { "deleted": true }` only when deletion is complete. A retryable Clerk failure
   returns `502`, leaving the iOS session available for retry.

The flow is idempotent and its local deletion, tombstone, concurrency, retry and resurrection
checks already passed. Do not redesign or weaken it. In particular:

- preserve the `DELETE /api/account` request and response contract;
- preserve `GET /api/me` and every `/api/saved-palettes` contract;
- preserve the tombstone and shared provisioning/deletion lock;
- do not move token revocation into the iOS client;
- do not require Apple reauthentication merely to delete an account;
- do not let Apple/Clerk revocation failure restore already-deleted ColorSense data;
- do not log Apple tokens, authorization codes, client-secret JWTs, Clerk bearer tokens, Clerk IDs,
  relay addresses, private keys or `.p8` contents.

The iOS repository contains no Apple access or refresh token. Clerk owns the Sign in with Apple
exchange, so this task begins with verifying what Clerk does and what server-side credentials or
provider tokens the existing integration can access.

## Work to execute

### 1. Inspect the real deletion and Apple-auth paths

In the deployed ColorSense backend and its matching source revision:

1. Identify the exact `DELETE /api/account` handler and the function that deletes the Clerk user.
2. Identify how a Clerk identity's provider is read. The decision must use verified Clerk external
   account/provider metadata, not an email-domain guess; Hide My Email addresses are not proof of
   provider identity.
3. For an Apple-created purpose-made test user, inspect which Apple credentials Clerk and the
   backend retain or expose server-side: authorization code, access token, refresh token, or none.
   Do not print their values.
4. Check Clerk's installed SDK behavior, source/documentation and actual API response to establish
   whether deleting a Clerk user automatically calls Apple's revocation endpoint. A successful
   Clerk delete or absence of an exception is not proof of Apple revocation.
5. Record the exact client identifier used by this native authorization. It must match the
   `client_id` originally sent to Apple. Do not assume that the native bundle ID and the web
   Services ID are interchangeable.

If Clerk already performs Apple revocation, do not add duplicate infrastructure. Proceed directly
to the acceptance test and return the evidence that proves the behavior.

### 2. Implement revocation only if it is missing

Prefer a supported Clerk mechanism that revokes the upstream Apple connection as part of user
deletion. If Clerk exposes no such operation but provides a usable Apple refresh/access token to
the server, add revocation to the existing deletion orchestration before deleting the Clerk
identity:

1. Generate the short-lived Apple client-secret JWT server-side using the existing dedicated Sign
   in with Apple key stored in Replit Secrets. Never reuse or expose the App Store Connect In-App
   Purchase key.
2. Call `POST https://appleid.apple.com/auth/revoke` with
   `application/x-www-form-urlencoded` fields `client_id`, `client_secret`, `token`, and the matching
   `token_type_hint`.
3. Treat Apple's `200` as success; Apple documents it as idempotent for an already-invalid token.
4. Treat transport failures and Apple error responses as retryable deletion failures, while
   preserving the existing local deletion/tombstone state and preventing account resurrection.
5. Never persist a client-secret JWT. Store any long-lived Apple token encrypted at rest with the
   narrowest practical access, and delete it when revocation succeeds.

Before implementing custom token storage or changing the Apple authorization exchange, stop and
report the exact Clerk limitation and proposed data flow. That would be a security-sensitive scope
expansion and must not be improvised.

### 3. If programmatic revocation is impossible

If neither Clerk nor the backend has a usable Apple authorization code, refresh token or access
token, do not block or undo account deletion and do not fabricate a successful revocation result.
Return evidence of the limitation and specify the smallest user-facing fallback required by Apple
TN3194:

- the exact deletion-result copy or screen that should direct an Apple user to revoke ColorSense in
  Apple Account settings;
- how the app/backend will recognize the later revoked credential state or Apple
  `consent-revoked` notification;
- whether an Apple server-to-server notification endpoint is already registered and handles
  `consent-revoked` safely.

Do not ship new fallback copy or create new Apple infrastructure without Chris's approval. This
section is a factual escalation path, not authorization to change the iOS app.

## Acceptance test

Use a purpose-made Apple account/ColorSense user. Never use or modify a real customer's account.
Do not record its Apple address, relay address, password, verification code, tokens or Clerk ID in
the response.

1. Confirm Apple's authorization sheet shows a first authorization for ColorSense.
2. Create the ColorSense account with Sign in with Apple and save one disposable palette.
3. Confirm from Clerk metadata that the identity is Apple-backed.
4. Delete the account through the production `DELETE /api/account` path used by iOS.
5. Confirm the endpoint result, local-row deletion, palette deletion, one tombstone, Clerk-user
   deletion, and absence of account resurrection. These are regression checks, not new design work.
6. Prove Apple authorization was revoked using one of these acceptable evidence paths:
   - a captured, redacted successful Apple `/auth/revoke` response tied to the deletion attempt; or
   - a documented Clerk audit/event record that explicitly confirms upstream Apple revocation;
     merely confirming Clerk-user deletion is insufficient.
7. Attempt Sign in with Apple again. The Apple UI should behave as a fresh authorization rather
   than silently returning the old authorization. Confirm a new empty ColorSense account is created
   and the deleted palette does not return.
8. Repeat the delete request or the underlying revocation operation to prove idempotency without
   recreating data or producing a 500.

If Apple UI caching makes step 7 ambiguous, say so and rely on direct server/Clerk revocation
evidence. Do not sign a personal device out of iCloud or manipulate a real account to force the UI.

## Required automated checks

Add or identify tests proving:

- non-Apple users retain the existing deletion behavior and do not call Apple;
- Apple users take the verified revocation path based on provider metadata;
- Apple success completes deletion;
- an already-revoked token remains idempotent;
- Apple timeout/error follows the documented retry behavior without account resurrection;
- secrets and tokens are absent from logs and API responses;
- `GET /api/me` and `/api/saved-palettes` response contracts are unchanged.

Run the backend test suite, typecheck and production build. Deploy only after they pass.

## Required response

Return a concise completion report with:

1. Deployed backend revision and deletion-handler file/function.
2. How Apple-backed identities are detected.
3. Whether Clerk automatically revokes the upstream Apple authorization: **yes**, **no**, or
   **unproven**, with the exact evidence.
4. Which usable Apple credential is available server-side, stated by type only; never its value.
5. Exact client identifier used for revocation, if implemented (safe to show).
6. Files and database schema changed, if any.
7. Automated checks and results.
8. Production acceptance-test results for every step above, with sensitive values redacted.
9. Deployment status.
10. One verdict:
    - `programmatic Apple revocation verified — submission item closed`;
    - `manual-revocation fallback required — iOS decision needed`; or
    - `blocked`, with the precise missing access, credential or Clerk capability.

Do not mark the item closed based only on source inspection, a Clerk-user deletion, or a proposed
implementation. It closes only with direct evidence that Apple authorization was revoked, or after
Chris explicitly accepts and ships Apple's manual-revocation fallback.
