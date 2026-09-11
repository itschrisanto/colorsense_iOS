# ColorSense iOS — privacy audit

> **Final archive update, 2026-09-11:** audited Release archive
> `.build/testflight/ColorSense-1.0-6.xcarchive`. The native app uses authenticated
> `DELETE /api/account`, and a destructive production-iPhone test passed deletion, automatic
> sign-out, relaunch, signed-out tools and fresh Google reauthentication with no restored saved
> data. Replit reports local deletion, tombstoning and Clerk identity deletion. Its controlled
> backend suite subsequently passed forced `502`, retry/idempotency and stale-identity protection
> (9/9 tests). Direct inspection of the original production rows is unavailable without the
> deleted identity's Clerk ID.

Requested before updating the public privacy policy and submitting to the App Store. Every finding
below is from the source, the SDK configuration, the dependency manifest or the database schema.
Nothing is inferred from UI copy or intent. Where something could not be proved, it says so.

Audited 2026-09-05 against `main`, updated 2026-09-10 for Apple In-App Purchase, and reconciled
against build `1.0 (6)` on 2026-09-11. PostHog iOS **3.71.2** and Clerk iOS **1.5.1** are resolved.

## Verdict

**The iOS privacy claims now match the shipping code and observed production behavior.** The former
account-deletion blocker is closed at the user-visible level. App Store submission still depends on
the release checklist, including backend-only deletion fault tests and StoreKit lifecycle work.

---

## Claim-by-claim

| # | Proposed claim | Status | Evidence | Data sent, and where | Change needed | Policy wording | Apple label |
|---|---|---|---|---|---|---|---|
| 1 | Photos stay on the device, used only to extract colours, never uploaded or retained | **Accurate** | The app's four direct `URLSession` call sites are confined to `SavedPaletteService` (2), `FeedbackService` (1) and `AccountDeletionService` (1). None takes an image, image data, metadata or filename. `PhotoSourcePicker`, `PhotoExtractor`, `ColorExtractionService` and `CameraPicker` contain no networking at all | Nothing | None | "Photos you choose from your library, and photos you take with the camera in the app, stay on your device. They are used only to work out the colours in them, and are never uploaded to ColorSense or anyone else." | Photos: **not collected** |
| 2 | Palette extraction and WCAG contrast run entirely on device | **Accurate** | `ColorExtractionService` (k-means), `ContrastCalculator`, `PaletteHealth`, `ColorScheme`, `ColorHarmony`, `SvgRecolor`, `VisualizerScenes` are all pure Swift with no network calls | Nothing | None | "Working out a palette, checking contrast, scoring a palette and generating colour schemes all happen on your phone. No image or colour value is sent to a server for these." | n/a |
| 3 | Analytics are pseudonymous and not connected to a ColorSense account | **Accurate** | `identify`, `alias` and `group` appear nowhere in the app — only in comments. `personProfiles = .always` keeps a profile against PostHog's own random install ID, which is not an account identifier | Event name plus counts and closed enum values, to PostHog | None | See wording below | Product Interaction, Other Usage Data: **not linked**, not for tracking |
| 4 | Analytics can be turned off under Account, and that stops the SDK | **Accurate** | `isOptedOut` persists in `UserDefaults`; the setter calls PostHog's own `optOut()` / `optIn()`. Critically `config.optOut = isOptedOut` is set **before** `PostHogSDK.shared.setup(config)`, so an opted-out install sends nothing at all, including the `app_opened` event captured immediately after setup | Nothing while opted out | None | "You can turn analytics off in the app under Account. That switches the analytics SDK itself off rather than only stopping ColorSense from recording events, and it is remembered between launches." | Optional, user can opt out |
| 5 | Crash reports contain technical diagnostics only | **Partially accurate — must be qualified** | `errorTrackingConfig.autoCapture = true` captures unhandled errors and native crashes; `exceptionSteps.enabled = false` means no breadcrumb trail. But an exception's *message* is not controlled by us, and a Swift error surfaced from a file name, a URL or a decoding failure could carry user-derived text | Stack traces, device model, OS version, exception type and message, to PostHog | None required, but **do not claim reports never contain user content** | "If the app crashes we receive a crash report containing stack traces and technical details such as device model and operating system version. We do not attach your photos, palettes or colour values to these reports. Crash reports can include the text of the error itself, which in rare cases may mention a file name." | Crash Data, Other Diagnostic Data: **not linked** |
| 6 | No advertising SDKs, no cross-app tracking | **Accurate** | The direct SDK integrations are Clerk and PostHog; Nuke and PhoneNumberKit are resolved Clerk dependencies. No `AdSupport`, `AppTrackingTransparency`, `ASIdentifierManager`, `advertisingIdentifier`, Firebase, Adjust, AppsFlyer, Branch or Google Mobile Ads appears in the app. `PrivacyInfo.xcprivacy` declares `NSPrivacyTracking` **false** | n/a | None | "The ColorSense app contains no advertising and no tracking software. Google Analytics and Google AdSense run on the ColorSense website only, and are not present in the app." | Used for tracking: **No** |
| 7 | An account is optional | **Accurate** | Onboarding's account ask has a "Maybe later" exit. Extractor, Contrast, Health, Schemes, SVG Recolor and Visualizer all work signed out. Only saving to the account and the Library require sign-in | Bearer token from Clerk | None | "An account is optional. The colour tools work without one. Signing in lets you save palettes to your account so they appear on colorsense.online too." | Contact Info, Identifiers, User Content: **linked** |
| 8 | Sign in with Apple is available | **Accurate** | Build 6 carries the production Sign in with Apple entitlement. New-account, returning-account and cancellation flows passed on physical devices, and Hide My Email with relay delivery passed on an external tester's device on 2026-09-12 | Apple identity data handled through Clerk | None | The deployed policy may name Apple | Contact Info and User ID already declared |
| 9 | Deleting your account removes your saved palettes | **Accurate in the tested production flow** | `DeleteAccountView` calls authenticated `DELETE /api/account` and signs out only after `{deleted:true}`. A production iPhone deletion followed by Google reauthentication restored none of the deleted saved data | Clerk token and account identifier; no user content is added to the request | Complete backend fault injection/direct database verification | The deployed September 11 deletion wording matches the tested flow | n/a |

---

## Resolved mismatch: account deletion

The original audit found that `DeleteAccountView` called Clerk's `user.delete()` directly, leaving
server-side ColorSense rows behind. That implementation has been replaced.

Build 6 calls the server-owned, authenticated `DELETE /api/account` lifecycle. Replit reports that
the endpoint deletes agreed local data, writes a permanent Clerk-ID tombstone under the same
advisory lock as provisioning, and then deletes the Clerk identity. The client treats `502` as a
partial identity-deletion failure and preserves the session so the operation can be retried safely.

A purpose-made production account with a saved palette was deleted from an iPhone. The app signed
out, remained signed out after force-quit/relaunch, and continued to provide the signed-out tools.
Google reauthentication produced an empty account and restored none of the deleted saved data.
Focused client tests cover success, `401`, `502`, malformed success and transport failure. Direct
database inspection and forced backend partial-failure/idempotency checks remain outstanding.

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
| `permission_denied` | `permission` ("photos", "camera") |
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
- **Apple purchase record** — Apple's signed transaction, submitted with a Clerk bearer token to
  `/api/iap/apple/transactions`. The backend verifies and retains its transaction, product and date
  fields against the ColorSense account to grant and restore Pro.
- **Account deletion** — an authenticated `DELETE /api/account` request. It carries the Clerk bearer
  token needed to identify the account and no additional user content.
- **Nothing else.** No image, analytics payload or device identifier goes to the ColorSense API.

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

> **Account deletion.** You can permanently delete your account from Account settings in the iOS
> app. This removes your ColorSense profile, saved palettes, linked feature data and sign-in
> identity across the app and website. Some purchase, accounting, security and independently
> subscribed mailing records may be retained where required. Deleting the account does not cancel
> an active Apple or website subscription, which must be cancelled separately.

---

## Recommended App Store Connect privacy labels

| Data type | Linked | Tracking | Purpose | Optional |
|---|---|---|---|---|
| Email address | Yes | No | App functionality (account) | Yes, account is optional |
| Name | Yes | No | App functionality (account) | Yes |
| User ID | Yes | No | App functionality (account) | Yes |
| User content (saved palettes) | Yes | No | App functionality | Yes |
| Customer support (feedback messages) | Yes | No | App functionality | Yes |
| Purchase history | Yes | No | App functionality (Pro entitlement) | Yes |
| Product interaction | No | No | Analytics | Yes, opt-out in app |
| Other usage data | No | No | Analytics | Yes, opt-out in app |
| Crash data | No | No | App functionality (diagnostics) | Yes, follows the same opt-out |
| Other diagnostic data | No | No | App functionality (diagnostics) | Yes |

**Photos are not collected** and must not be declared as collected. The library is read on device
and nothing leaves it.

**GeoIP correction, 2026-09-10:** a production PostHog query found IP-derived country properties on
all historical iOS events and city properties on some of them. ColorSense does not use location
analytics. `AnalyticsService` now applies `$geoip_disable: true` to every event that passes its
allowlist, including `$exception`. PostHog project `590983` was also changed to
`anonymize_ips: true` and read back as enabled on 2026-09-10.

**Live follow-up, 2026-09-10:** the check passed against TestFlight build `1.0 (5)`. A fresh
`app_opened` event arrived at `2026-09-10T03:30:13.088Z`. It carried `$geoip_disable: true`, had no
country code, country name, city, latitude or longitude properties, and stored no `$ip` value. A
separate read-only project API check reconfirmed `anonymize_ips: true`. This closes the runtime
GeoIP and IP-storage verification required before omitting Coarse Location from App Store Connect.

Permission strings present and correct in `project.yml`: `NSCameraUsageDescription`,
`NSPhotoLibraryUsageDescription`, `NSPhotoLibraryAddUsageDescription`. The privacy manifest declares
`NSPrivacyTracking` false, UserDefaults (`CA92.1`) and file timestamp (`C617.1`) reasons.

---

## Remaining verification before submission

1. Complete the StoreKit renewal/refund/revocation lifecycle check tracked in the submission guide.

Sign in with Apple Hide My Email and relay delivery passed on 2026-09-12 and are no longer open.

No new privacy-label category was introduced by the account-deletion endpoint.
