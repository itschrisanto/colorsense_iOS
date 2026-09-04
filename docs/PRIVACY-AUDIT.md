# ColorSense iOS — privacy audit

Requested before updating the public privacy policy and submitting to the App Store. Every finding
below is from the source, the SDK configuration, the dependency manifest or the database schema.
Nothing is inferred from UI copy or intent. Where something could not be proved, it says so.

Audited 2026-09-05 against `main` at the Schemes commit. PostHog iOS **3.71.2** (resolved), Clerk
iOS SDK, no other third-party SDKs.

## Verdict

**Not safe to publish as proposed — one claim fails.** Account deletion does not delete server-side
data, and the app currently tells users that it does. Everything else audited is accurate.

---

## Claim-by-claim

| # | Proposed claim | Status | Evidence | Data sent, and where | Change needed | Policy wording | Apple label |
|---|---|---|---|---|---|---|---|
| 1 | Photos stay on the device, used only to extract colours, never uploaded or retained | **Accurate** | The whole app has exactly three outbound call sites: `SavedPaletteService` (2) and `FeedbackService` (1). None takes an image, image data, metadata or filename. `PhotoSourcePicker`, `PhotoExtractor`, `ColorExtractionService` and `CameraPicker` contain no networking at all | Nothing | None | "Photos you choose from your library, and photos you take with the camera in the app, stay on your device. They are used only to work out the colours in them, and are never uploaded to ColorSense or anyone else." | Photos: **not collected** |
| 2 | Palette extraction and WCAG contrast run entirely on device | **Accurate** | `ColorExtractionService` (k-means), `ContrastCalculator`, `PaletteHealth`, `ColorScheme`, `ColorHarmony`, `SvgRecolor`, `VisualizerScenes` are all pure Swift with no network calls | Nothing | None | "Working out a palette, checking contrast, scoring a palette and generating colour schemes all happen on your phone. No image or colour value is sent to a server for these." | n/a |
| 3 | Analytics are pseudonymous and not connected to a ColorSense account | **Accurate** | `identify`, `alias` and `group` appear nowhere in the app — only in comments. `personProfiles = .always` keeps a profile against PostHog's own random install ID, which is not an account identifier | Event name plus counts and closed enum values, to PostHog | None | See wording below | Product Interaction, Other Usage Data: **not linked**, not for tracking |
| 4 | Analytics can be turned off under Account, and that stops the SDK | **Accurate** | `isOptedOut` persists in `UserDefaults`; the setter calls PostHog's own `optOut()` / `optIn()`. Critically `config.optOut = isOptedOut` is set **before** `PostHogSDK.shared.setup(config)`, so an opted-out install sends nothing at all, including the `app_opened` event captured immediately after setup | Nothing while opted out | None | "You can turn analytics off in the app under Account. That switches the analytics SDK itself off rather than only stopping ColorSense from recording events, and it is remembered between launches." | Optional, user can opt out |
| 5 | Crash reports contain technical diagnostics only | **Partially accurate — must be qualified** | `errorTrackingConfig.autoCapture = true` captures unhandled errors and native crashes; `exceptionSteps.enabled = false` means no breadcrumb trail. But an exception's *message* is not controlled by us, and a Swift error surfaced from a file name, a URL or a decoding failure could carry user-derived text | Stack traces, device model, OS version, exception type and message, to PostHog | None required, but **do not claim reports never contain user content** | "If the app crashes we receive a crash report containing stack traces and technical details such as device model and operating system version. We do not attach your photos, palettes or colour values to these reports. Crash reports can include the text of the error itself, which in rare cases may mention a file name." | Crash Data, Other Diagnostic Data: **not linked** |
| 6 | No advertising SDKs, no cross-app tracking | **Accurate** | Only two packages ship: `clerk-ios` and `posthog-ios`. No `AdSupport`, `AppTrackingTransparency`, `ASIdentifierManager`, `advertisingIdentifier`, Firebase, Adjust, AppsFlyer, Branch or Google Mobile Ads anywhere. `PrivacyInfo.xcprivacy` declares `NSPrivacyTracking` **false** | n/a | None | "The ColorSense app contains no advertising and no tracking software. Google Analytics and Google AdSense run on the ColorSense website only, and are not present in the app." | Used for tracking: **No** |
| 7 | An account is optional | **Accurate** | Onboarding's account ask has a "Maybe later" exit. Extractor, Contrast, Health, Schemes, SVG Recolor and Visualizer all work signed out. Only saving to the account and the Library require sign-in | Bearer token from Clerk | None | "An account is optional. The colour tools work without one. Signing in lets you save palettes to your account so they appear on colorsense.online too." | Contact Info, Identifiers, User Content: **linked** |
| 8 | Sign in with Apple is available | **Not implemented** | The entitlement is attached to Release only, and is not provisioned. Live methods are email and Google | n/a | Do not mention Apple by name until it ships | Use "supported third-party sign-in providers" | n/a |
| 9 | Deleting your account removes your saved palettes | **INACCURATE — blocks publication** | See below | n/a | **Backend fix required** | Do not publish until fixed | n/a |

---

## The one mismatch: account deletion

**The app's own copy is currently false.** `DeleteAccountView` tells the user:

> "Deleting your account removes your saved palettes and profile from ColorSense. This can't be
> undone, and it applies everywhere — the web app too."

What the code actually does is call Clerk's `user.delete()`. That removes the Clerk identity and
nothing else. The chain then breaks:

- `savedPalettesTable.userId` references `usersTable.id` with `onDelete: "cascade"`, so **if** the
  ColorSense user row were deleted, the palettes would go with it. That part is correct.
- **Nothing deletes that row.** There is no Clerk webhook route registered in the api-server's
  router list, no `user.deleted` handler, and no `db.delete(usersTable)` call anywhere in the
  server or the shared db package. The only `db.delete` on palettes is the per-palette
  `DELETE /saved-palettes/:id` endpoint.

So after a user deletes their account from the app or the website, their ColorSense database row and
every saved palette remain. The cascade is armed and never fires.

**This must be fixed before submission**, on the backend, not in the app. Apple expects an in-app
account deletion to actually delete the account's data, and the policy we are about to publish would
be describing behaviour that does not exist.

The fix is a Clerk `user.deleted` webhook that deletes the corresponding `usersTable` row, letting
the existing cascade remove the palettes. **Do not change the `/api/saved-palettes` or `/api/me`
response contracts while doing it — the iOS app depends on both.**

Until that lands there are two honest options, and it is Chris's call:

1. **Fix the backend** and keep the app's copy as it is. Preferred, and it is the only option that
   makes the claim true.
2. **Soften the in-app copy** to say the sign-in identity is removed and that saved palettes are
   deleted on request via hello@colorsense.online. Accurate, but a worse experience and still a
   weak answer for App Review.

I have not changed the copy, because either choice is a product decision and shipping a quietly
weakened promise is worse than an explicit one.

---

## Complete list of analytics events

Every event is a case of the closed `AnalyticsService.Event` enum, and a `beforeSend` allowlist
admits only these plus PostHog's `$exception`. Anything else the SDK might generate is dropped.

| Event | Properties |
|---|---|
| `app_opened` | none |
| `palette_extracted` | `source` ("camera") |
| `palette_generated` | `colors` (count) |
| `extraction_failed` | `source` ("library", "library_fallback") |
| `palette_saved` | `colors` (count) |
| `palette_shared` | none |
| `color_copied` | `from` ("band") |
| `color_added` | none |
| `color_removed` | none |
| `color_reordered` | none |
| `tool_opened` | `tool` (enum raw value) |
| `contrast_checked` | none |
| `permission_denied` | `permission` ("photos") |
| `feedback_sent` | none |
| `svg_file_opened` | `colors` (count) |
| `onboarding_viewed` | none |
| `onboarding_mood` | `mood` (enum raw value) |
| `onboarding_choice` | `exit` (enum raw value) |
| `pro_formats_seen` | `formats` (count) |

**No property carries user content.** Every value is a count, a fixed string, or a raw value from a
closed Swift enum. No hex value, palette name, colour name, file name, photo, message text, email or
Clerk identifier is attached to any event. `feedback_sent` deliberately records only that feedback
was sent; the message itself goes to the API's own table and never to PostHog.

**Autocapture:** screen views, element interactions, application lifecycle, surveys and push are all
explicitly disabled rather than left at their defaults, precisely so an SDK update cannot widen
collection silently. Session replay is off. Screen tracking is not automatic; there is none.

---

## What the app sends to the ColorSense API

- **Saved palettes** — `{name, colors}` with a Clerk bearer token, to `/api/saved-palettes`. Colour
  values and a name the user typed. Linked to the account by design; that is the feature.
- **Plan** — a read of `/api/me` with the bearer token.
- **Feedback** — `{name, email, message}` to `/api/feedback`, all typed by the user on that form.
- **Nothing else.** No image, no analytics, no device identifier.

The app never posts the email address, name or profile image to the ColorSense API. The server
derives the user from the Clerk token.

---

## Copy-ready privacy-policy section

> **The ColorSense iOS app**
>
> The iOS app follows the same principles as the website, with a few differences worth stating
> plainly.
>
> **Photos stay on your device.** The app reads your photo library only to show you a picker and to
> work out the colours in a picture you choose. Photos you take with the camera in the app are
> treated the same way. No image, thumbnail, file name or piece of image data is ever uploaded to
> ColorSense or to anyone else, and nothing is kept after the colours are read.
>
> **The colour tools run on your phone.** Extracting a palette, checking WCAG contrast, scoring a
> palette and generating colour schemes all happen on the device, with no network request.
>
> **Analytics.** The app uses PostHog to understand which features get used. It is pseudonymous: it
> uses a random identifier PostHog generates for the installation, and we never connect it to your
> ColorSense account. There is no session replay and no automatic recording of taps or screens. We
> record a short, fixed list of product events carrying counts and categories, never your colours,
> palette names, photos or anything you type. **You can turn analytics off in the app under
> Account**, which switches the analytics SDK itself off rather than only stopping us recording.
>
> **Crash reports.** If the app crashes we receive a report with stack traces and technical details
> such as device model and operating system version, so we can fix it. We do not attach your photos,
> palettes or colour values. A report includes the text of the error itself, which in rare cases may
> mention a file name.
>
> **No advertising, no tracking.** The app contains no advertising and no tracking software. Google
> Analytics and Google AdSense run on the website only. We do not share your data with data brokers
> and we do not track you across other companies' apps or websites.
>
> **Accounts.** An account is optional and the colour tools work without one. Signing in, with an
> email address or a supported third-party sign-in provider, lets you save palettes to your account
> so they also appear on colorsense.online. Authentication is handled by Clerk, and we receive the
> email address and name on the account together with an account identifier.

*(The account deletion paragraph is deliberately missing. Add it once the backend cleanup exists,
and not before.)*

---

## Recommended App Store Connect privacy labels

| Data type | Linked | Tracking | Purpose | Optional |
|---|---|---|---|---|
| Email address | Yes | No | App functionality (account) | Yes, account is optional |
| Name | Yes | No | App functionality (account) | Yes |
| User ID | Yes | No | App functionality (account) | Yes |
| User content (saved palettes) | Yes | No | App functionality | Yes |
| Product interaction | No | No | Analytics | Yes, opt-out in app |
| Other usage data | No | No | Analytics | Yes, opt-out in app |
| Crash data | No | No | App functionality (diagnostics) | Yes, follows the same opt-out |
| Other diagnostic data | No | No | App functionality (diagnostics) | Yes |

**Photos are not collected** and must not be declared as collected. The library is read on device
and nothing leaves it.

Permission strings present and correct in `project.yml`: `NSCameraUsageDescription`,
`NSPhotoLibraryUsageDescription`, `NSPhotoLibraryAddUsageDescription`. The privacy manifest declares
`NSPrivacyTracking` false, UserDefaults (`CA92.1`) and file timestamp (`C617.1`) reasons.

---

## Must fix before submission

1. **Account deletion does not delete server-side data.** Backend Clerk `user.deleted` webhook, or
   an explicit deletion endpoint. Blocks the deletion claim entirely.
2. **Do not name Sign in with Apple** in the policy or the listing until it is provisioned and live.

Nothing else found. No code changes were required on the iOS side, and none were made.
