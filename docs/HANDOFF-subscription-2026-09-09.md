# Handoff: Subscription screen, 2026-09-09

For whoever is holding the StoreKit and App Review screenshot work. Short-lived: fold what matters
into `docs/APP-STORE-SUBMISSION.md` and delete this file once we are not both in the same view.

## We are both in `SubscriptionView.swift` right now

At the time of writing the working tree holds **two sets of uncommitted changes in one file**, from
two people. Nothing is committed, deliberately.

**Yours** (also `ColorSense/App/ColorSenseApp.swift`):

- a `-iap-review-*` Debug launch mode that opens `SubscriptionView` directly
- `init()` in `SubscriptionView`, a `reviewCaptureProduct` stored property, fixed prices, a forced
  Free state, and a `.task` guard that skips `load()` in capture mode

**Mine**, in the same file:

- `HeroColorConfetti` only: a `@Environment(\.dynamicTypeSize)` property, and its body split so the
  chips render through a new `chips` property, guarded by `if !typeSize.isAccessibilitySize`

The two touch **disjoint regions** — yours is the initializer, a property and `.task` near the top;
mine is one private view near the bottom. **I did not commit**, because staging the file would have
swept your work-in-progress into my commit. If you revert only your own hunks, mine survives. If you
`git checkout --` the whole file, mine goes with yours, so check before you do.

## What I changed, and the measurement behind it

**The hero's decorative chips were landing on the paragraph at accessibility sizes.**
`HeroColorConfetti` positions four chips at fixed fractions of the hero's size. The hero grows with
the type inside it, so the headline and paragraph expand into the corners the chips occupy. Measured
at accessibility-extra-large: the teal chip covered the first character of "Create, refine and
export", and the yellow chip sat inside the same paragraph.

The decoration now hides at accessibility sizes rather than being repositioned. There is no fixed
position that stays clear at every size, and a reader at those sizes is asking for words rather than
confetti. The gradient and Lauma stay, so nothing reads as missing.

Evidence, captured through **your** launch mode (which is what made this reachable without a signed
in account, so thank you): `.build/subscription-sweep/` — `01-light-medium`, `02-dark-medium`,
`03-light-axl` (the collision), `04-axl-fixed`.

Dark mode and the default size were both already correct and are unchanged.

## Two things I did not do

- **The cross-platform Pro benefit.** The redesign brief's third benefit is "Keep Pro access across
  ColorSense when signed in"; the shipped row says "Keep the Extractor and WCAG checker free"
  instead. That satisfies a different requirement but drops the answer to "am I buying this twice?"
  on a screen that requires an account before it will sell anything. Left alone because you are in
  the file. See the status note at the top of `docs/SUBSCRIPTION-REDESIGN-BRIEF.md`.
- **The scroll check on a device.** The simulator cannot scroll, so "purchase and exit controls stay
  reachable" at accessibility sizes is still unverified on hardware. At those sizes the hero fills
  more than a full screen, so this is a real check rather than a formality.

## One thing to carry into your own work

Your capture scaffolding is well guarded — `#if DEBUG`, nil in Release, and `load()` still runs
normally outside capture mode. The risk is not the code, it is that "I will remove it afterwards" has
no verification step. `docs/APP-STORE-SUBMISSION.md` section 3a now treats the removal as a release
blocker: confirm the launch mode and the fixed price table are gone from the tree, and grep the
Release build for the capture flag rather than trusting the removal happened. Same rule this repo
already applies to the temporary crash trigger and to the photo-picker harness, which lives on
`diagnostics/photo-picker-repro` rather than main for exactly this reason.
