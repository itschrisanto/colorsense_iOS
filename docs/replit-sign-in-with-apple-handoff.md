# Replit handoff: enable native Sign in with Apple

## Objective

Enable **native Sign in with Apple** for the existing ColorSense iOS app in the existing
Replit-managed **production Clerk instance**. The iOS app already contains the native capability
and uses ClerkKitUI's `AuthView`, so this task is primarily production Clerk configuration plus a
check that Apple-created users work with the existing ColorSense API.

This scope is for the native iOS flow. Replit's production Apple-provider form combines the native
bundle registration with custom Apple OAuth credentials. Although the native Apple API itself does
not require web OAuth credentials, Replit's production configuration requires a Services ID and a
Sign in with Apple private key before it will save the provider. Configure those credentials in the
existing Replit-managed tenant; do not build a custom OAuth endpoint.

## Fixed project values

- Product: ColorSense
- App Store name: ColorSense: Palette Studio
- Bundle ID: `online.colorsense.ios`
- Apple Developer Team ID: `L53K68TJHL`
- Expected App ID Prefix: `L53K68TJHL`
- Apple Services ID to register: `online.colorsense.auth` (if available)
- Native callback URL already used by the app: `online.colorsense.ios://callback`
- Production API: `https://colorsense.online/api`
- Clerk proxy used by iOS and web: `https://colorsense.online/api/__clerk`
- The iOS app uses the same production Clerk publishable key and user store as colorsense.online.

When Clerk asks for **App ID Prefix**, verify it against the Apple Developer identifier or signed
provisioning profile. It is expected to equal the Team ID above, but do not silently substitute a
different value.

## Existing iOS work

The iOS repository already has:

- `com.apple.developer.applesignin = Default` in its entitlements;
- Sign in with Apple provisioned for Debug and Release signing;
- `ClerkKit` and `ClerkKitUI` configured against the production Clerk instance;
- Clerk's prebuilt `AuthView` on sign-in and onboarding screens;
- the URL callback scheme registered;
- `online.colorsense.ios://callback` allowlisted in Clerk;
- working production email-code and Google sign-in on a physical iPhone;
- working authenticated requests to `/api/me` and `/api/saved-palettes`.

Clerk's native iOS documentation says `AuthView` displays the Apple button automatically after the
Apple social connection and Native Application are configured. No custom Swift Apple button or
custom token-exchange endpoint should be needed.

## Work to complete in the existing production Clerk tenant

1. Open the Clerk instance already provisioned for ColorSense by Replit. Confirm its publishable
   key is the same production key currently injected as `CLERK_PUBLISHABLE_KEY` and
   `VITE_CLERK_PUBLISHABLE_KEY`.
2. Confirm Clerk's Native API is enabled. It likely already is because native email and Google
   authentication work, but record the result.
3. In Clerk **Native applications**, add or update the iOS application:
   - App ID Prefix: `L53K68TJHL` after verification
   - Bundle ID: `online.colorsense.ios`
4. In Clerk **SSO connections**, add Apple **For all users**, or open the existing Apple connection.
5. Enable Apple for both sign-up and sign-in on the production instance.
6. In Apple Developer, register the Services ID `online.colorsense.auth`, associate it with the
   primary App ID `online.colorsense.ios`, and add every domain and Return URL shown in Replit's
   Provider setup panel. At the time of setup, the displayed values are:
   - Domains: `agent-assets--chrisantomende1.replit.app`, `colorsense.online`
   - Return URLs:
     `https://agent-assets--chrisantomende1.replit.app/api/__clerk/v1/oauth_callback` and
     `https://colorsense.online/api/__clerk/v1/oauth_callback`
7. Create a dedicated Sign in with Apple key associated with `online.colorsense.ios`. Record its
   Key ID and download its `.p8` private key once. Store it securely.
8. Fill Replit's production Apple custom-credentials form as follows:
   - iOS app Bundle ID: `online.colorsense.ios`
   - Apple Services ID: `online.colorsense.auth`
   - Apple OAuth client secret: the complete `.p8` private-key contents, including the BEGIN and END
     lines (Replit's documentation calls this field the Apple Private Key)
   - Apple Key ID: the ID of the dedicated key
   - Apple Team ID: `L53K68TJHL`
9. Preserve the current email-code and Google options. Do not replace the production Clerk app,
   rotate its keys, or move ColorSense to another Clerk tenant.
10. Confirm that the existing `/api/__clerk` proxy continues to pass the native Clerk requests.
   Avoid changing this route unless the Apple flow reveals a reproducible proxy problem.
11. Inspect the backend's user resolution/synchronisation path. An Apple-authenticated Clerk user
   must be able to call `/api/me`, create or resolve the same ColorSense `users` row used by other
   sign-in methods, and save/read palettes without provider-specific assumptions.
12. Confirm that the backend treats Apple's relay email addresses as valid email addresses. Do not
   require a Gmail address, a non-relay domain, or a first/last name. Apple supplies a person's name
   only on first authorization, and it can be absent.
13. If ColorSense or Clerk sends application email to users who choose **Hide My Email**, inspect
    Clerk's Apple Private Email Relay guidance and report any sender-domain/email-source setup still
    required. Do not claim relay delivery is configured unless it has been tested.

## Do not build for this native-only task

- Do not create a second Clerk application or user store.
- Do not change the production Clerk publishable key or secret key.
- Do not add a custom Apple token verification or exchange endpoint; Clerk owns that step.
- Do not add a separate web authentication implementation. The Services ID and key above exist only
  to satisfy Replit's production Apple-provider configuration.
- Do not remove Google or email authentication.
- Do not commit Clerk secrets, Apple keys, or `.p8` contents to the repository.
- Do not modify `/api/me` or `/api/saved-palettes` response contracts.

## Validation

After configuration, coordinate a physical-device Release-build test and capture the result of each
case:

1. The Apple button appears in Clerk's `AuthView` on both onboarding and Account sign-in.
2. A first-time user can select **Share My Email**, finishes sign-in, reaches an active Clerk
   session, loads `/api/me`, saves a palette, and sees it on colorsense.online.
3. A first-time user can select **Hide My Email** and completes the same flow.
4. A returning Apple user signs into the same Clerk/ColorSense account without creating duplicate
   user or entitlement rows.
5. Cancelling the Apple sheet returns to the sign-in screen without creating a partial account or
   trapping the UI.
6. Email-code and Google sign-in still work.
7. Sign-out and sign-in restore the expected account and saved palettes.

For a clean repeat of Apple's first-authorization test, deleting the Clerk user alone is
insufficient. Also revoke ColorSense under the test device's Apple Account settings for apps using
Sign in with Apple.

## Deliverable back to the iOS team

Return:

- confirmation that the existing **production** Clerk tenant was used;
- confirmation of the Native Application values saved;
- confirmation that Apple is enabled for sign-up and sign-in;
- whether any code or proxy change was needed, with file names and commit/diff if so;
- results for every validation case above;
- any remaining manual action, naming the exact dashboard, page, field, and value;
- no secret values or private-key contents.

If Replit's Auth pane does not expose Clerk's **Native applications** or Apple connection settings,
stop before creating replacement infrastructure. Report exactly which setting is inaccessible so
the account owner can perform that one dashboard action in the existing tenant.

## Authoritative references

- Clerk native iOS Sign in with Apple:
  <https://clerk.com/docs/ios/guides/configure/auth-strategies/sign-in-with-apple>
- Clerk iOS quickstart and Native Application registration:
  <https://clerk.com/docs/ios/getting-started/quickstart>
- Apple Sign in with Apple capability:
  <https://developer.apple.com/help/account/capabilities/about-sign-in-with-apple>
