# Handoff: the App Review demo account

Completed for the app-level review record on 2026-09-10. A dedicated Free Clerk account was created
and validated through a returning sign-in on the physical device. Its credentials, review contact
information and reviewer notes were saved directly in App Store Connect for both the app-level
review and Beta App Review. The credentials are intentionally absent from this repository.

## Why it is not optional

The purchase path fetches a backend-issued `appAccountToken` through an **authenticated** request
before it calls StoreKit, and the entitlement binds to a Clerk account. A signed-out reviewer reaches
the paywall and stops there, and In-App Purchase is precisely what they have to exercise to approve
the app. Leaving App Store Connect's sign-in-required field empty while a core flow needs a login is
a routine "Information Needed" rejection and a full round trip.

It unblocked the app-level App Review Information, the three IAP records and Beta App Review for
external TestFlight testing.

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

- [x] Signing in on a **physical device** reaches the signed-in Account state.
- [x] **Account → Subscription** shows three products with real prices, not a loading or error state.
      This is the screen the reviewer needs and it is signed-in only.
- [x] The account reads as **Free**, so the paywall offers something to buy.
- [x] **Library** loads, both saved palettes and saved colors, even when empty.
- [x] A Sandbox purchase completes and Pro activates, then **Restore Purchases** works. These checks
      passed with separate purchase-test accounts, leaving the dedicated review account Free.

## Where the credentials go, and where they must not

App Store Connect only: the app-level and Beta **App Review Information** sections now have the
sign-in-required box, credentials, contact information and reviewer notes. The three IAP records
have their product notes. Keep a separate copy in a password manager.

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
