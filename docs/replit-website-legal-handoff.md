# Replit handoff: update the ColorSense Privacy Policy and Terms of Service

> **Completed, 2026-09-11:** both September 11 pages are live. Cache-bypassed asset inspection
> confirmed Privacy section 11 names website Account settings, the in-app iOS deletion control and
> email; Terms section 2 names the website and iOS controls and retains the separate-subscription-
> cancellation warning. Replit reports typecheck, production build, prerendering and SEO checks
> passed. The account-deletion flow itself still needs the purpose-made production-account test
> tracked in `docs/APP-STORE-SUBMISSION.md` section 9.

## Objective

Update and deploy the public legal pages at:

- `https://colorsense.online/privacy-policy`
- `https://colorsense.online/terms`

Both pages must cover the ColorSense website, Chrome extension, and iOS app and must describe the
production implementation accurately. The current live Privacy Policy is dated May 22, 2026 and
mostly covers the website and Chrome extension. The current live Terms page is dated May 7, 2026
and describes ColorSense only as a free browser-based image palette tool.

Expected source files in the Replit project:

- `artifacts/color-palette/src/pages/PrivacyPolicy.tsx`
- `artifacts/color-palette/src/pages/Terms.tsx` (confirm the actual path before editing)

Use **Terms of Service** consistently in the page heading, document title, footer/navigation label,
and iOS-facing wording. Keep the existing `/terms` URL so the released iOS app's link remains valid.

## Before writing public claims

Inspect the production code and configuration, including the website, API server, database schema,
Clerk setup, analytics, email/newsletter integration, affiliate scripts, payment integration, and
the iOS facts below. The policy and terms must describe what is actually deployed; this handoff is
not permission to invent retention periods, security guarantees, refund promises, governing law,
or data practices.

Two related items are being completed separately and affect the final wording:

1. **Account deletion:** deleting a Clerk user currently does not delete the corresponding
   ColorSense database row or saved palettes. Do not publish a claim that profile data and palettes
   are deleted until the verified Clerk `user.deleted` webhook has been implemented and tested end
   to end. If the legal pages must deploy first, describe the current deletion/request path
   accurately and flag this as an App Store blocker.
2. **Sign in with Apple:** name Apple as an available sign-in method only after it is enabled on the
   existing production Clerk tenant and passes the native iOS tests. Until then, say “supported
   third-party sign-in providers.”

Return discrepancies instead of weakening or overstating a privacy promise silently.

## Privacy Policy changes

### 1. Scope and identity

- Broaden the opening scope from visitors to the website to users of `colorsense.online`, the
  ColorSense Chrome extension, and the ColorSense iOS app.
- Brand name: `ColorSense`, capital C and S, one word.
- Operator/developer: Chrisanto Mendez.
- Contact: `hello@colorsense.online`.
- Update the displayed revision date to the real deployment date.
- Do not say that accepting the Privacy Policy is the legal basis for every processing activity.

### 2. Accounts and synced user content

Explain in plain language:

- An account is optional. The core iOS colour tools work while signed out; an account enables saved
  palettes/library sync and account-related features.
- Clerk handles authentication. ColorSense receives the Clerk user identifier and the account's
  email address and name when available. Apple relay email addresses and missing names are valid.
- Supported sign-in methods must match the production Clerk configuration at deployment time.
- Saved palettes contain colour values and user-supplied palette names. They are stored in the
  ColorSense database and can sync between the website and iOS app under the same account.
- State the verified account deletion process. Claim deletion of the local profile and palettes
  only after the Clerk deletion webhook and database cascade have passed end-to-end tests.
- Explain how users can contact `hello@colorsense.online` about access, correction, or deletion.
  Do not promise a response deadline that the business has not adopted.

### 3. Website-specific collection and services

Audit the current site before finalising this section. At minimum, the deployed site currently
references Google Analytics, Ahrefs Analytics, Lemon Squeezy affiliate tracking, Google AdSense
configuration, Clerk, and the website's Lemon Squeezy payment flow. It also has feedback/contact and
newsletter functionality. State which services are actually active, what they receive, their
purpose, and whether cookies or similar storage are used.

Keep these distinctions accurate:

- Website image processing occurs in the browser; the image itself is not uploaded to ColorSense.
- The website may save extracted HEX colours to its public palette library. Disclose this accurately
  after checking the current implementation; do not turn “the image is not uploaded” into “nothing
  from the extraction is collected.”
- Google Analytics, Ahrefs, affiliate tracking, AdSense, and Lemon Squeezy website checkout do not
  run inside the native iOS app or Chrome extension merely because the website uses them.
- If AdSense is configured but ads are not active, describe the deployed state rather than implying
  either active ad serving or permanent absence.
- Identify feedback/contact and newsletter processors from the source and production settings. Do
  not name a vendor based only on an unused dependency or secret.

Link to material third-party privacy information where the existing page style permits it. Do not
paste third-party policies into ColorSense's policy.

### 4. ColorSense iOS app

Add a dedicated section with these verified behaviors:

- **Photos and camera images stay on the device.** The app accesses only an image the user chooses
  or takes and processes it locally. It does not upload the image, thumbnail, image bytes, filename,
  or photo metadata. The selected image is not retained after extracting the colours.
- **Colour tools run locally.** Palette extraction, WCAG contrast calculations, palette health,
  colour schemes, SVG recolouring, and visualizer rendering run on the device. Network requests are
  used for account, saved-palette, entitlement, feedback, analytics, and purchase-related functions,
  as applicable; do not claim the entire app is offline.
- **Saved content is deliberate.** Colour values and palette names go to the ColorSense API only
  when a signed-in user explicitly saves them. Photos are not part of the saved record.
- **Authentication.** Clerk processes sign-in. The app and website use the same production Clerk
  user store.
- **Product analytics.** The app uses PostHog with a random installation identifier that ColorSense
  does not connect to the Clerk account. No session replay, automatic tap/screen capture, advertising
  attribution, or cross-company tracking is enabled. The app sends a fixed event allowlist with
  counts/categories and does not send colours, palette names, photos, or free-form user text.
- **Analytics control.** Users can disable analytics under Account. The setting is applied before
  PostHog starts on later launches and disables analytics and crash reporting together.
- **Crash diagnostics.** PostHog can receive stack traces, exception messages, device model, and OS
  version. Do not promise that exception messages can never contain user content; application code
  does not deliberately attach photos, palettes, colour values, or screen contents.
- **No advertising or tracking in iOS.** The app has no ads, AdSense, Google Analytics, IDFA/ATT,
  ad-attribution SDK, or cross-app tracking.
- **Purchases.** Apple processes native in-app purchases. Describe purchase data only after checking
  the final StoreKit and server reconciliation implementation. ColorSense will receive transaction
  and entitlement information needed to provide Pro access; it does not receive the customer's full
  Apple payment-card details.
- Apple distributes the app through the App Store and publishes its own privacy information.

The final App Store Connect privacy answers must be reconciled with this wording and with the final
Release build. Current expected iOS disclosures are account contact information/identifiers and
saved user content linked to the user, plus pseudonymous product interaction/usage and diagnostics
that are not used for tracking. Do not state that the iOS app collects no data.

### 5. Chrome extension

Preserve the existing dedicated Chrome extension section unless the extension's current code audit
shows it has changed. Keep its local processing/storage and no-analytics claims specific to the
extension. Do not make the website's cookies or the iOS app's PostHog behavior sound as if they run
inside the extension.

### 6. Standard policy topics

Retain and update, where supported by the implementation:

- purposes for using data;
- storage and retention, without invented fixed periods;
- sharing with processors and legal obligations;
- security stated as reasonable safeguards, not absolute security;
- children's privacy;
- international processing if applicable to the named processors;
- user choices and rights, phrased so they do not overpromise rights outside applicable law;
- changes to the policy;
- contact details.

Preserve the existing British spelling and plain-language tone.

## Terms of Service changes

### 1. Scope

- Make the Terms apply to the ColorSense website, Chrome extension, iOS app, accounts, synced saved
  content, free tools, Pro features, subscriptions, and Pro Pass.
- Replace website-only wording such as “please do not use this website” with wording covering all
  ColorSense services.
- Update the displayed revision date to the real deployment date.

### 2. Accounts

Cover account eligibility and responsibility in plain language:

- Accounts are optional for core tools and required for account/sync and paid entitlements.
- Users are responsible for lawful use of their account and for keeping access credentials secure.
- Explain suspension/termination for material misuse without claiming arbitrary ownership of user
  content.
- Describe account deletion consistently with the verified implementation and Privacy Policy.
- Do not equate the App Store's 4+ content rating with a declaration that children under 13 may open
  a ColorSense account independently.

### 3. User content, uploads, and generated output

- Users retain ownership of images they choose, palette names, and other content they provide.
- Grant ColorSense only the limited permission needed to process, store, sync, display, or delete
  content for the feature the user requests.
- Explain accurately whether website-extracted HEX palettes can enter the public palette library.
- Users must have the right to use content they provide and must not submit unlawful or harmful
  material.
- State whether generated palettes, exports, and other tool output may be used personally and
  commercially. Avoid promising uniqueness, non-infringement, brand suitability, or guaranteed
  accessibility compliance.
- Make clear that WCAG scores and design suggestions are tools; users remain responsible for final
  testing and decisions.

### 4. Acceptable use and intellectual property

Preserve the existing rules against unlawful use, disruptive automation, and attempts to interfere
with the service. Keep ColorSense ownership language for its code, site content, design assets, and
branding, subject to third-party/open-source licences and the user's ownership of their content.
Avoid an absolute ban on reverse engineering where applicable law or open-source licences permit it.

### 5. Website purchases

Confirm the production Lemon Squeezy checkout, billing portal, subscription cancellation, tax,
refund, and fulfilment behavior from the actual implementation and merchant settings. Then state:

- who processes the payment and acts as merchant of record, if that is accurate for the configured
  account;
- that checkout shows the current price, currency, billing period, trial/offer, and applicable taxes;
- how a customer manages or cancels a website subscription;
- where refund requests go and which displayed policy governs them;
- when access ends after cancellation.

Do not copy Apple's billing language onto website purchases. Do not promise refunds or fixed terms
that conflict with the checkout or mandatory consumer law.

### 6. iOS purchases

Describe the final native products after StoreKit is live:

- **ColorSense Pro Monthly:** auto-renewable monthly subscription. The configured one-week free
  introductory offer applies only when Apple shows the customer as eligible.
- **ColorSense Pro Annual:** auto-renewable annual subscription.
- **ColorSense Pro Pass:** a separate one-month, one-time consumable purchase. It does not
  auto-renew and can be purchased again after access expires.
- The App Store purchase sheet displays the actual localized price, currency, billing period, and
  offer terms before confirmation. Avoid hard-coding USD prices as universally applicable legal
  terms.
- Apple charges the customer's Apple Account. Apple manages native billing, cancellation, and
  eligible refund requests.
- Auto-renewable subscriptions continue until cancelled. Cancellation prevents a future renewal and
  ordinarily leaves access through the already-paid period, subject to Apple's terms and actions such
  as refunds or revocation.
- Customers manage subscriptions through their Apple Account/App Store subscription settings and
  request eligible Apple refunds through Apple's official process.
- StoreKit purchase restoration applies to restorable subscription entitlements; do not describe the
  consumable Pro Pass as an Apple-restorable purchase.
- Entitlements may sync to supported ColorSense surfaces when the customer signs into the same
  ColorSense account and the server has validated the purchase. Do not promise transfer between
  different ColorSense or Apple accounts.

Link to Apple's subscription management/refund information and the Apple Standard EULA. Use Apple's
Standard EULA for the iOS app unless the account owner deliberately chooses and reviews a custom
App Store licence agreement. These website Terms can supplement service-specific rules but must not
claim to replace Apple's mandatory App Store terms.

### 7. Affiliate links, third-party services, warranties, and liability

Preserve the existing affiliate disclosure and third-party-link sections. Broaden the warranty and
liability wording from “website” to the relevant ColorSense services, keep it subject to applicable
consumer law, and avoid guarantees about uninterrupted availability, generated results, permanent
storage, or error-free operation.

Do not invent a governing-law jurisdiction, mandatory arbitration clause, class-action waiver, or
legal entity that the owner has not selected. Flag those as owner/legal-review decisions if the
current Terms do not contain them.

### 8. Contact and changes

- Keep `hello@colorsense.online` and the About-page contact form.
- Explain that material Terms changes will be posted with an updated date. Do not claim that silence
  waives rights where applicable law requires notice or consent.

## Presentation and routing constraints

- Preserve the existing React/Tailwind layout, header, footer, responsive behavior, typography, and
  numbered-section structure unless a small change is needed for readability.
- Keep both routes public, reachable without signing in, usable on mobile, and returning HTTP 200 on
  a direct visit and refresh.
- Keep canonical URLs exactly `https://colorsense.online/privacy-policy` and
  `https://colorsense.online/terms`.
- Provide meaningful page titles and meta descriptions for each legal page.
- Keep all links keyboard accessible and visibly styled.
- Do not expose environment variables, Clerk secrets, webhook secrets, Apple transaction data, or
  customer records in source, logs, screenshots, or the rendered pages.

## Validation and deliverable

Before reporting completion:

1. Run the project's formatter, typecheck, tests, and production build.
2. Deploy the production site.
3. Open both public URLs directly in a signed-out browser and refresh each one.
4. Test both pages at a narrow mobile viewport and with keyboard navigation.
5. Confirm the Privacy Policy contains the iOS photo-locality, Clerk account, saved-palette, PostHog,
   analytics opt-out, crash diagnostic, no-iOS-ads/tracking, and deletion wording described above.
6. Confirm the Terms cover website and iOS billing separately, monthly/annual auto-renewal, the
   eligibility-limited monthly trial, the non-renewing consumable Pro Pass, Apple cancellation and
   refund routing, user content, and account deletion.
7. Confirm the text does not name Sign in with Apple before it is live and does not claim complete
   account-data deletion before the backend fix is verified.
8. Compare the deployed text with the actual source files to ensure CDN/build output is current.

Return:

- files changed;
- the final deployed URLs and displayed revision dates;
- a short list of processors/services verified as active;
- the exact account deletion behavior verified;
- whether Sign in with Apple was live when the wording was deployed;
- website and iOS purchase/cancellation/refund wording implemented;
- checks run and their results;
- any factual or legal decision still needed from the account owner.

Do not return secrets or real customer data.

## Reference material

- iOS implementation/privacy audit supplied by the iOS team:
  `docs/PRIVACY-AUDIT.md`
- App Store submission facts supplied by the iOS team:
  `docs/APP-STORE-SUBMISSION.md`
- Apple App Privacy requirements:
  <https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/>
- Apple Standard EULA:
  <https://www.apple.com/legal/internet-services/itunes/dev/stdeula/>
- Apple subscription and billing support:
  <https://support.apple.com/billing>
