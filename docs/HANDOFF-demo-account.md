# Handoff: the App Review demo account

For whoever holds browser and App Store Connect access. The repo-side agent cannot do this: creating
a Clerk user needs either a browser, a tap-through of `AuthView`, or `CLERK_SECRET_KEY`. This repo
holds only the publishable key, and `osascript` has no assistive access on this machine, so there is
no scripted route to the sign-up form. It is a five-minute task for someone with a browser.

## Why it is not optional

The purchase path fetches a backend-issued `appAccountToken` through an **authenticated** request
before it calls StoreKit, and the entitlement binds to a Clerk account. A signed-out reviewer reaches
the paywall and stops there, and In-App Purchase is precisely what they have to exercise to approve
the app. Leaving App Store Connect's sign-in-required field empty while a core flow needs a login is
a routine "Information Needed" rejection and a full round trip.

It unblocks three items at once: the app-level App Review Information, the three IAP records, and
Beta App Review for external TestFlight testers.

## The account must be Free, and this is the part that is easy to get wrong

**Do not use an account that already has Pro**, and do not grant it Pro to be helpful. The reviewer's
job is to complete a purchase; an already-entitled account shows them the "Pro active" state and
nothing to buy, so the flow they must test is invisible.

Two ways an account acquires Pro without anyone intending it, both worth avoiding:

- `GET /api/me` runs `reconcileEntitlement(email)`, which grants Pro if Lemon Squeezy recorded a paid
  entitlement **for that email address**. Use an address with no purchase history.
- A voucher redemption. Do not redeem one on this account.

## Making it

1. **Use an alias, not a personal inbox and not Chris's own account.** `hello+appreview@` on the
   brand domain is the first choice: it is already the monitored support address, and it keeps a
   personal address out of a committed file. If that mail host does not support plus-addressing,
   any `+alias` on an inbox you already watch is fine. The point is that the verification code has
   to be readable by whoever is signing up.
2. Sign up on colorsense.online, or in the app through the onboarding account beat. Email code is
   simpler than Google or Apple here, because a reviewer never touches the mailbox afterwards.
3. Use a long random password from a password manager.

## It only counts as working when all of these pass

- [ ] Signing in on a **physical device** reaches the signed-in Account state.
- [ ] **Account → Subscription** shows three products with real prices, not a loading or error state.
      This is the screen the reviewer needs and it is signed-in only.
- [ ] The account reads as **Free**, so the paywall offers something to buy.
- [ ] **Library** loads, both saved palettes and saved colors, even if empty.
- [ ] A Sandbox purchase completes and Pro activates, then **Restore Purchases** works.
      Afterwards, decide whether to leave it Pro or make a second Free account: the reviewer needs
      Free, so if the test leaves it entitled, reset or recreate it before submitting.

## Where the credentials go, and where they must not

App Store Connect only: **App Review Information**, with the sign-in-required box ticked, plus the
review notes on each of the three IAP records (section 3a of `docs/APP-STORE-SUBMISSION.md` drafts
those). Put a copy in a password manager.

**Never commit them.** Not to this repo, not to a doc, not to a comment. `Config/Secrets.xcconfig` is
gitignored and is for build values, not review credentials, so it is not the right home either.

## One risk to accept deliberately before review

Guideline 5.1.1(v) means a reviewer may well **delete the demo account** to check that in-app
deletion exists. Two consequences:

- The account disappears mid-review and has to be recreated.
- **Deletion does not currently remove server-side data.** `docs/replit-account-deletion-handoff.md`
  is the open blocker. If a reviewer deletes the account, the app's own copy tells them their
  palettes are gone while the rows remain. That is a live gap between what the app claims and what
  happens, and it is a better reason to land the deletion webhook before submission than any
  checklist entry.
