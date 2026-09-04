Update the ColorSense privacy policy so it covers the iOS app.

File: `artifacts/color-palette/src/pages/PrivacyPolicy.tsx`

## Why

The policy currently scopes itself to "the website colorsense.online". We are submitting a native
iOS app to the App Store, and App Review checks that the linked privacy policy actually covers the
app. It also has to match the App Privacy labels we declare in App Store Connect. Right now it does
not mention mobile at all.

Section 7 (the Chrome extension) is the pattern to follow: a per-platform section in plain language.
Please match it.

## What to change

**1. Broaden the scope in section 1.** It currently says the policy explains how we handle
information "when you visit our site". Make it cover all three surfaces: the website
colorsense.online, the ColorSense Chrome extension, and the ColorSense iOS app.

**2. Add a new section covering accounts.** The policy does not currently mention accounts at all,
which is a gap on the web as well as on iOS. Cover:

- Accounts are optional on the web and requested (but not required) in the iOS app.
- Authentication is handled by Clerk. We receive the email address and name associated with the
  account, and a user ID.
- Sign-in options include email and Google. (Sign in with Apple will be added on iOS; you can
  mention third-party sign-in providers generally rather than listing one that is not live yet.)
- Signed-in users can save palettes to their account. Saved palettes are colour values and the names
  the user gives them. They sync between the website and the iOS app because both use the same
  account and the same API.
- How to delete: a user can delete their account from their profile, which removes their saved
  palettes, and can contact hello@colorsense.online for help.

**3. Add a new section for the iOS app**, in the same shape as section 7. It must state:

- **Photos stay on the device.** The app reads the photo library only to show a picker and to
  extract a palette from a chosen image. Images are never uploaded, copied to our servers, or
  retained. The same is true of photos taken with the camera inside the app.
- **The colour tools run on the device.** Extracting a palette and checking WCAG contrast happen
  entirely on the phone, with no network request.
- **Analytics.** The iOS app uses PostHog for product analytics. It is pseudonymous: PostHog's own
  randomly generated installation identifier is used and we never associate analytics with a
  ColorSense account. There is no session replay and no automatic recording of taps or screens; we
  record a fixed, closed list of product events. **Analytics can be turned off in the app, under
  Account**, and turning it off stops the SDK rather than merely muting our own calls.
- **Crash diagnostics.** If the app crashes, a crash report is sent to PostHog so we can fix it.
  Reports contain stack traces and technical diagnostics such as device model and OS version. They
  do not contain photos, palette names, colour values, or the contents of anything on screen.
- **No advertising and no tracking in the app.** The iOS app contains no ads, no Google Analytics,
  no AdSense, and no advertising or tracking SDKs. We do not share data with data brokers and we do
  not track users across other companies' apps or websites.
- Distribution is through the Apple App Store, and Apple shows its own privacy summary on the
  listing.

**4. Make the web-only parts explicit.** Section 3 currently describes Google Analytics and Google
AdSense without saying where they apply. Say plainly that those apply to the website only, and that
the iOS app and the Chrome extension contain neither. Without that, a reviewer reading the policy
alongside our App Store privacy labels will see a mismatch.

**5. Update "Last updated"** at the top to today's date.

## Constraints

- **Match the existing page's British spelling.** The page already uses "programmes",
  "personalised" and "enquiry". Keep that. Do not convert the page to American spelling.
- **Brand name is always `ColorSense`** — capital C, capital S, one word. Never "Colorsense",
  "Color Sense", or "ColorSense.online" as a brand name. The domain is colorsense.online.
- Keep the existing visual structure: numbered `<section>` blocks with `<h2>` headings styled the
  same way, and the same Tailwind classes already in the file. Renumber the later sections rather
  than appending out of order.
- Plain language, same register as the rest of the page. No legal boilerplate we cannot stand
  behind, and no claims beyond the list above.
- Do not claim the app collects nothing. It does collect account data, pseudonymous analytics and
  crash diagnostics, and the policy has to say so.

## Do not change

- The affiliate, third-party links, children's privacy, data security, changes and contact sections,
  beyond renumbering.
- The Chrome extension section's content.
- The contact address: hello@colorsense.online.

## How I will check it

I will read the deployed page at colorsense.online/privacy-policy and confirm it mentions the iOS
app by name, says photos never leave the device, names PostHog and the in-app opt-out, describes
crash reporting, states that AdSense and Google Analytics are website-only, and covers accounts and
deletion. Those points have to survive to the live page.
