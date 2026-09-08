# Subscription redesign brief

> **Status: implemented in `038273a`, verified against this brief on 2026-09-09.** Kept as the
> record of what was asked for and why, not as work to do. `SubscriptionView` carries the hero with
> Lauma and the "Make every color count" headline, `HeroColorConfetti` supplies the restrained
> colour objects that replaced the reference's floating banknotes, the three product cards gate the
> trial on `isEligibleForIntroOffer`, the primary label follows the selection, and the paid state
> leads with Pro active without naming a product. It was refactored into the private components
> this brief predicted.
>
> **One point was not carried across.** Benefit three below is "Keep Pro access across ColorSense
> when signed in"; the shipped row says "Keep the Extractor and WCAG checker free" instead. That
> satisfies the free-tools requirement further down, but it drops the answer to "am I buying this
> twice?" on a screen that requires an account before it will sell anything. Worth revisiting, and
> the reason CLAUDE.md flags the App/Website benefits split as the part of Coolors' paywall worth
> borrowing.
>
> Still unevidenced: the accessibility-size and dark-appearance sweep of this specific screen, which
> the interaction requirements below ask for.

Requested by Chris on 2026-09-07. Implement after the StoreKit notification work is complete.
The reference is a playful subscription sheet with a decorative hero, mascot, benefit list,
selectable products, one purchase button and legal/restore links. Adapt the structure to ColorSense;
do not copy the reference branding, money pattern or exact styling.

## Direction

- Playful, simple and unmistakably a color app.
- Use ColorSense's existing brand palette, type and Lauma mascot assets.
- Replace the reference's floating banknotes with restrained color objects: swatches, palette chips,
  color wheels or small overlapping cards. Keep the hero calm enough that Lauma remains the focus.
- Reuse an approved Lauma asset such as `LaumaCelebrate`, `LaumaGuide` or `LaumaStanding`; select the
  best pose during visual iteration rather than adding a new illustration prematurely.
- Keep the existing sheet dismissal behavior and all StoreKit/backend logic intact.

## Proposed free-account layout

1. A compact ColorSense hero with Lauma and a short headline such as **Make every color count**.
2. Three concise benefits grounded in shipping features:
   - Export palettes and color work
   - Use every Pro creative tool
   - Keep Pro access across ColorSense when signed in
3. Three selectable StoreKit cards:
   - Monthly, including the seven-day trial only when StoreKit reports eligibility
   - Annual
   - Pro Pass, clearly described as one month and non-renewing
4. One primary button whose label follows the selected product, for example **Start Monthly**,
   **Choose Annual** or **Get Pro Pass**.
5. Plain links for **Restore Purchases**, **Terms** and **Privacy** beneath the primary action.
6. StoreKit supplies every displayed price. Never hardcode USD or imply that Pro Pass renews.

## Paid-account layout

- Lead with a compact **Pro active** state and Lauma rather than showing a purchase CTA.
- Because `/api/me` exposes the effective plan but not the originating StoreKit product, do not
  claim that Monthly, Annual or Pro Pass is the current product unless the backend contract is
  expanded with verified product information.
- Keep Restore Purchases available and preserve clear account-ownership errors.

## Interaction and review requirements

- Selecting a plan must not begin a purchase. Only the primary button opens Apple's purchase sheet.
- Disable selection and purchase controls while purchasing or restoring, and show progress without
  changing the chosen product.
- Preserve VoiceOver labels, Dynamic Type, Reduce Motion and dark appearance.
- Fit an iPhone SE through iPhone 17 Pro Max. The hero may compress; purchase and exit controls must
  remain reachable by scrolling.
- Keep Extractor and the WCAG checker identified as free where the page discusses free access.
- Do not add a web checkout link or mention Lemon Squeezy inside the iOS app.
- Validate purchase, cancellation, pending, backend rejection, cross-account restore and Pro Pass
  backend restore after the redesign.

## Likely implementation seam

Refactor `ColorSense/Features/Auth/SubscriptionView.swift` into small private view components while
preserving `load()`, `purchase(_:)`, `restore()`, `ProStoreRegistry` and the backend entitlement
source. The visual redesign must not alter transaction finishing or ownership rules.
