# Replit follow-up: publish the ColorSense Apple purchase backend

The ColorSense App Store account prerequisites are now complete: Paid Apps Agreement, banking and
tax information are Active; DSA trader compliance is complete; and a dedicated In-App Purchase key
has been generated and downloaded. The iOS client now implements the backend-issued
`appAccountToken` contract and remains disabled behind `STOREKIT_PURCHASES_ENABLED` until sandbox
purchase and lifecycle testing succeeds.

External production probes on 2026-09-07 confirmed that both authenticated IAP routes return `401`
without a Clerk session and that the public webhook returns `400 Invalid signed payload` for an
empty POST. The owner also confirmed that all five IAP secret values below were added to Replit.
These checks establish that the routes are deployed; the remaining evidence below is still needed
for migrations, real Apple verification and entitlement reconciliation.

## Secrets the owner will add through Replit Secrets

Use these exact names unless the implemented backend already uses documented equivalents:

- `APPLE_IAP_PRIVATE_KEY` — the complete contents of the downloaded In-App Purchase `.p8`, including
  the `BEGIN PRIVATE KEY` and `END PRIVATE KEY` lines;
- `APPLE_IAP_KEY_ID` — the Key ID shown for that In-App Purchase key;
- `APPLE_IAP_ISSUER_ID` — the Issuer ID shown on the App Store Connect In-App Purchase keys page;
- `APPLE_IAP_BUNDLE_ID` — `online.colorsense.ios`;
- `APPLE_IAP_APP_APPLE_ID` — `6809134374`.

Do not ask for these values in chat, print them, return them in logs, commit them, or expose them to
the browser or iOS client. Read them only from the server environment.

## Required production work

1. Confirm the database migration and Apple entitlement tables are applied to production.
2. Confirm these authenticated production routes are deployed at `https://colorsense.online`:
   - `GET /api/iap/apple/app-account-token`
   - `POST /api/iap/apple/transactions`
3. Confirm the public notification route is deployed:
   - `POST /api/webhooks/apple/app-store`
4. Confirm the verifier accepts both production and sandbox Apple transactions using the exact
   bundle ID, App Apple ID and three allowlisted product IDs in the original handoff.
5. Confirm a new purchase is rejected when `appAccountToken` is absent, malformed, belongs to a
   different Clerk account, or differs from the verified transaction.
6. Confirm transaction replay and notification replay are idempotent, including the 31-day
   consumable Pro Pass.
7. Confirm `GET /api/me` computes the strongest entitlement across Apple, Lemon Squeezy, vouchers,
   admin and business access without one source revoking another.
8. Run the full backend test suite and publish the deployment.

Do not configure App Store Server Notification URLs until the public production webhook is live.
Once it is live, both Production and Sandbox in App Store Connect will use Version 2 and:

`https://colorsense.online/api/webhooks/apple/app-store`

## Reply with evidence

Return the deployment URL and timestamp, migration applied, secret names detected without values,
route status/auth behavior, verification library version, test totals, notification types handled,
and any remaining blocker. Explicitly state whether the backend is ready for physical-device
StoreKit sandbox testing. Do not claim readiness based only on development workspace behavior.
