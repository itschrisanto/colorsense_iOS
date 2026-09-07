# Follow-up to Replit: execute the Clerk-side Sign in with Apple setup

Your previous response restated and expanded the task but did not report any configuration changes
or results. Please execute the Replit-controlled work now and return factual evidence.

The iOS/Apple-side preflight is already complete:

- Bundle ID is `online.colorsense.ios`.
- Apple Developer Team ID is `L53K68TJHL`.
- The Sign in with Apple entitlement is in Debug and Release.
- Paid-team development and distribution signing have been verified.
- A signed Release archive and App Store Connect export have succeeded with the Apple entitlement.
- The callback scheme `online.colorsense.ios://callback` is registered and allowlisted.
- ClerkKitUI `AuthView` is already used in onboarding and Account sign-in.
- The app already uses the production Clerk instance, `/api/__clerk` proxy, and production API.

Do not repeat Apple Developer, Xcode, archive, or physical-device work. The iOS team will run the
device validation after the production Clerk configuration changes.

## Execute these tasks in the existing production ColorSense Clerk tenant

1. Open the ColorSense Replit project's production Auth/Clerk configuration.
2. Confirm the existing production tenant is the one used by the current
   `CLERK_PUBLISHABLE_KEY`/`VITE_CLERK_PUBLISHABLE_KEY`. Do not print either key.
3. Confirm Clerk's Native API is enabled.
4. In Clerk **Native applications**, add or verify:
   - App ID Prefix: `L53K68TJHL`
   - Bundle ID: `online.colorsense.ios`
5. In Clerk **SSO connections**, add or edit Apple **For all users** and enable it for sign-up and
   sign-in.
6. Replit's production custom-credentials form also requires Apple provider credentials. Configure:
   - iOS Bundle ID: `online.colorsense.ios`
   - Services ID: register `online.colorsense.auth` and associate it with the primary App ID
     `online.colorsense.ios`
   - Domains: `agent-assets--chrisantomende1.replit.app`, `colorsense.online`
   - Return URLs: both exact callback URLs displayed by Replit's Provider setup panel
   - Apple OAuth client secret field: complete contents of the dedicated Sign in with Apple `.p8`
     private key, including its BEGIN/END lines, as specified by Replit's documentation
   - Apple Key ID: the dedicated key's identifier
   - Apple Team ID: `L53K68TJHL`
7. Preserve email-code and Google authentication.
8. Inspect the API's user resolution path and confirm it uses the authenticated Clerk user ID rather
   than assuming Google, Gmail, a non-relay email domain, or a non-empty first/last name.
9. Confirm `/api/me` and `/api/saved-palettes` have no provider-specific logic that would reject an
   Apple user. Do not change either response contract.
10. Report whether any ColorSense email sender must be registered with Apple Private Email Relay for
   delivery to `privaterelay.appleid.com` addresses. Do not claim this is configured without evidence.
11. Deploy only if source/backend changes were actually required. Clerk dashboard settings should be
    saved directly in the existing production tenant.

Do not create a second Clerk tenant, custom Apple token endpoint, or new user database. The Services
ID and private key above are required by Replit's production provider form and must remain secret.

## Required response

Return a short completion report containing:

1. Existing production Clerk tenant used: yes/no.
2. Native API enabled: yes/no.
3. Native Application saved:
   - App ID Prefix (safe to show)
   - Bundle ID (safe to show)
4. Apple enabled for sign-up and sign-in: yes/no.
5. Email-code and Google preserved: yes/no.
6. Backend provider-assumption findings, with file paths and lines changed if applicable.
7. Relay-email sender configuration status.
8. Deployment/build checks run for any Replit code changes.
9. Exact remaining manual action, if blocked: dashboard, page, field, and required value.
10. Verdict: `ready for iOS device testing` or `blocked`, with the reason.

Do not return another proposed plan. Perform the accessible configuration first. If Replit does not
expose **Native applications** or **SSO connections**, report that exact access limitation and stop
without creating replacement infrastructure.
