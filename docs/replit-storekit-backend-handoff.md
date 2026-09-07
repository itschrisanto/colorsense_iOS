# Replit handoff: reconcile ColorSense iOS StoreKit purchases

> Status update, 2026-09-07: Replit reported the transaction endpoint and a new authenticated
> `GET /api/iap/apple/app-account-token` route implemented in development. The iOS client now
> fetches that server-issued UUID before a purchase and passes it as StoreKit's `appAccountToken`.
> Production deployment, Apple server credentials, notification configuration and sandbox
> acceptance tests are still unverified.

## Objective

Add secure, idempotent Apple In-App Purchase reconciliation to the existing ColorSense production
API at `https://colorsense.online/api`. The iOS client now uses StoreKit 2, but deliberately does
not finish a transaction until this API verifies Apple's signed JWS and returns an active ColorSense
plan. The existing `GET /api/me` response shape and every saved-palette endpoint must remain
unchanged.

This is production billing work. Do not decode an unsigned payload, trust product IDs from the
client, use purchase timestamps supplied outside the JWS, or mark a user Pro before signature and
app-identity verification pass.

## Existing products

| Product | Product ID | App Store Connect Apple ID | Type |
|---|---|---:|---|
| Pro Monthly | `online.colorsense.ios.pro.monthly` | `6809206814` | Auto-renewable subscription |
| Pro Annual | `online.colorsense.ios.pro.annual` | `6809207967` | Auto-renewable subscription |
| Pro Pass | `online.colorsense.ios.pro.pass` | `6809208412` | Consumable, 31 days of Pro |

Subscription group: **ColorSense Pro**, group ID `22363784`. Monthly has a seven-day free
introductory offer. App bundle ID: `online.colorsense.ios`. App Apple ID: `6809134374`.

## Client contract already implemented

Authenticated request:

```http
POST /api/iap/apple/transactions
Authorization: Bearer <Clerk session token>
Content-Type: application/json

{"signedTransaction":"<StoreKit VerificationResult<Transaction>.jwsRepresentation>"}
```

Successful response:

```json
{"plan":"pro"}
```

The endpoint may return `business` when that is the account's stronger effective entitlement.
Return a non-2xx status for invalid JWS, wrong app, unknown product, ownership conflict or database
failure. The client keeps the StoreKit transaction unfinished and retries delivery later.

Relevant iOS files:

- `ColorSense/Services/ProStore.swift`
- `ColorSense/Services/SavedPaletteService.swift`
- `ColorSense/Features/Onboarding/OnboardingFlowView.swift`
- `ColorSense/Features/Auth/SubscriptionView.swift`

## Verification

Use Apple's official Node package, `@apple/app-store-server-library`, and its
`SignedDataVerifier.verifyAndDecodeTransaction`. Load Apple's current root CA certificates from
server-controlled files or secrets. Enable online certificate checks.

Create separate production and sandbox verifiers:

- bundle ID `online.colorsense.ios` for both;
- App Apple ID `6809134374` for production;
- `Environment.PRODUCTION` and `Environment.SANDBOX` respectively.

Try the production verifier first. Fall back to the sandbox verifier only for the library's precise
environment-mismatch result. Do not fall back after a bad signature, wrong bundle, wrong App Apple
ID, expired certificate or malformed payload.

After verification, require all of the following from the decoded JWS:

- `bundleId === "online.colorsense.ios"`;
- product ID is exactly one of the three allowlisted IDs above;
- transaction ID and original transaction ID are present;
- environment is the verifier's environment;
- the transaction is not revoked;
- subscription transactions have a valid future expiration or a state Apple says remains entitled;
- the product type matches the allowlist: subscriptions cannot enter the pass path and the pass
  cannot enter the subscription path.

Never log the JWS, Clerk bearer token, private key or complete decoded transaction.

## Persistence and ownership

Add Apple-specific tables to the Drizzle schema and push the migration. Names can follow the local
schema conventions, but preserve these invariants:

1. Every Apple `transactionId` is unique. Replaying the same JWS must not grant time twice.
2. Every `originalTransactionId` has one owning Clerk `userId`. Once bound by the authenticated
   client endpoint, another account must receive `403` and no entitlement. The iOS client also
   accepts `409` for compatibility with the original contract.
3. Store the product ID, user ID, environment, original transaction ID, transaction ID, purchase
   date, expiration date where applicable, revocation date/status and timestamps needed for audit.
   Do not persist the bearer token. Avoid persisting the complete JWS unless there is a documented
   operational need.
4. Foreign keys tied to the ColorSense user must cascade when the verified Clerk deletion webhook
   removes that user.

The insert, ownership binding and entitlement update must be one database transaction. A duplicate
transaction should return the already-computed effective plan successfully.

## Entitlement rules

The current backend stores Lemon Squeezy subscriptions, vouchers and Pro Pass time in
`users.plan/proExpiresAt`. Do not let one billing source revoke another.

- A live Apple monthly or annual subscription grants Pro through Apple's verified expiration,
  including Apple's supported grace-period state.
- A revoked/refunded or expired Apple subscription removes only the Apple grant.
- A Pro Pass grants 31 days, matching the existing `PRO_PASS_DAYS = 31`. Stack a new pass from the
  later of its verified purchase date or the end of the user's existing finite pass grant.
- Do not offer or apply a pass extension over an active open-ended/renewing Pro subscription.
- `GET /api/me` must return the strongest effective plan across admin/business, vouchers, Lemon
  Squeezy and Apple. A Lemon webhook must not downgrade active Apple access; an Apple notification
  must not downgrade active Lemon, voucher or admin access.
- Keep the existing response contract: `{ "user": { ..., "plan": "pro" } }`.

Refactor the entitlement helper if necessary so feature gates and `/api/me` use the same combined
calculation. Add regression tests for cross-source expiry and revocation.

## App Store Server Notifications V2

Add a public HTTPS endpoint such as:

```http
POST /api/webhooks/apple/app-store
Content-Type: application/json

{"signedPayload":"<Apple JWS>"}
```

Verify it with `SignedDataVerifier.verifyAndDecodeNotification` before reading any nested data.
Verify nested `signedTransactionInfo` and `signedRenewalInfo` too. Locate the owner by the previously
bound `originalTransactionId`, update Apple transaction/subscription state idempotently, then
recompute the effective entitlement. Respond with 2xx only after durable processing; use a failure
status when Apple should retry.

Handle at least purchase/renewal, expiration, billing retry or grace period, renewal-status change,
refund/revocation and offer redemption. Unknown verified notification types should be logged by
type and acknowledged without changing access.

## App Store Server API key

The Sign in with Apple `.p8` key is not the key for this job. In App Store Connect, create an
**In-App Purchase** key under **Users and Access → Integrations → In-App Purchase** and store its
private key, key ID and issuer ID only in Replit Secrets. This key is needed for App Store Server API
status/history recovery. Never commit it or return it to the client.

Required secrets should be named clearly, for example:

- `APPLE_IAP_PRIVATE_KEY`
- `APPLE_IAP_KEY_ID`
- `APPLE_IAP_ISSUER_ID`
- `APPLE_IAP_BUNDLE_ID=online.colorsense.ios`
- `APPLE_IAP_APP_APPLE_ID=6809134374`

The JWS verifier itself uses Apple root certificates; the In-App Purchase key authenticates calls
to the App Store Server API. Implement a reconciliation path that can query current subscription
status or transaction history after missed notifications.

## Required tests

- valid production and sandbox transaction fixtures;
- bad signature, malformed JWS, wrong environment, bundle ID, App Apple ID and product ID;
- transaction replay grants once;
- ownership conflict is rejected;
- pass replay does not add another 31 days;
- subscription purchase, renewal, grace period, expiration and refund;
- active Apple survives Lemon expiration;
- active Lemon/voucher/business survives Apple expiration;
- notification replay is idempotent;
- unauthenticated client delivery is rejected;
- `/api/me`, `/api/saved-palettes` and existing web purchases keep their contracts.

## Acceptance test

1. Deploy the backend and confirm the new route is reachable only with Clerk authentication.
2. Configure the Apple V2 production and sandbox notification URLs in App Store Connect.
3. Use a Sandbox Apple Account on a physical iPhone.
4. Buy monthly and confirm the seven-day offer appears only when StoreKit says the account is
   eligible.
5. Confirm the iOS app reports success only after `/api/me` returns Pro.
6. Confirm the same account is Pro on `colorsense.online`.
7. Test annual, cancellation, renewal/expiration and Restore Purchases.
8. Test one Pro Pass and replay its delivery; the second delivery must not extend access.
9. Confirm no real customer data or live charge was used.

Reply with the files changed, schema changes, route paths, environment variables added, verification
library version, notification types handled, test output, deployed URL and any remaining manual App
Store Connect step.
