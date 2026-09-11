# Replit handoff: make account deletion actually delete the account

> **Superseded implementation, 2026-09-11.** Replit completed account deletion on branch
> `audit/backend-hardening` with authenticated `DELETE /api/account`; it deliberately does not use
> the Clerk webhook designed below. The endpoint deletes and tombstones local data under a shared
> PostgreSQL advisory transaction lock before deleting the Clerk identity, is idempotent, treats a
> missing Clerk identity as success, and returns `502` when local deletion succeeded but Clerk
> deletion must be retried. `CLERK_WEBHOOK_SIGNING_SECRET` is obsolete. Keep the historical analysis
> below for why local cleanup and resurrection protection are required, but do not implement its
> webhook design. The current native work and remaining live verification are tracked in
> `docs/APP-STORE-SUBMISSION.md` section 9.

## Objective

Deleting a ColorSense account from the iOS app or the website must remove the user's server-side
data. Today it removes the Clerk identity and nothing else, so the app's own deletion copy and the
privacy policy wording we are about to publish are both false. This is a **submission blocker**:
App Store guideline 5.1.1(v) expects in-app account deletion to actually delete the account.

`docs/PRIVACY-AUDIT.md` found this on 2026-09-05 and named the fix as a Clerk `user.deleted`
webhook. This document is the implementation brief, and it adds two findings the audit did not
cover: the cascade reaches fewer tables than assumed, and there is a resurrection race that would
let a deleted row come back (and can email the person who just left).

**Verify everything below against the live repo before building.** The evidence here was read from
the local snapshot at `~/Documents/Codex/ColorSense/ColorSense`, whose last commit is
`d2350a0` (2026-09-02). The deployed backend may have moved since.

---

## 1. What happens today

`DeleteAccountView.swift` calls Clerk's `user.delete()` and stops there. On the server:

- There is **no webhook route of any kind for Clerk**. `artifacts/api-server/src/app.ts` mounts
  exactly one webhook router, `lemonWebhookRouter`, and `routes/index.ts` carries no Clerk entry.
- There is **no `db.delete(usersTable)` anywhere** in `artifacts/api-server/src`. The only palette
  deletion is the per-palette `DELETE /api/saved-palettes/:id`.
- The cascade is armed and never fires: `saved_palettes.user_id` references `users.id` with
  `onDelete: "cascade"` (`lib/db/src/schema/saved-palettes.ts:12`), but nothing deletes the `users`
  row for it to cascade from.

So after deletion the Clerk identity is gone, the ColorSense `users` row and every saved palette
remain, and the person has no way to reach them because the identity that authenticated them no
longer exists. That is the worst of both: the data survives and the owner cannot.

---

## 2. What a `users` row delete does and does not remove

Only **three** foreign keys cascade from `users.id`. Everything else holding a user identifier does
so as a plain column with no constraint, so a cascade will not touch it.

**Removed by the cascade:**

| Table | Column | Source |
|---|---|---|
| `saved_palettes` | `user_id` | `schema/saved-palettes.ts:12` |
| `feature_requests` | `author_user_id` | `schema/feature-requests.ts:41` |
| `feature_request_votes` | `user_id` | `schema/feature-requests.ts:64` |

Saved *colors* need no separate handling: iOS stores them as named one-swatch rows in
`saved_palettes`, so they cascade with everything else.

**Not removed, and each one needs a decision:**

| Table | Column | Note |
|---|---|---|
| `telegram_link_codes` | `user_id` (text, no FK) | Orphaned link codes |
| `telegram_account_links` | `user_id` (text, no FK) | A live bot binding to a user that no longer exists |
| `vouchers` | `redeemed_by_user_id` (text, no FK) | Redemption history |
| `feedback` | `email` | See below |
| `affiliate_applicants` | `email` | Separate application, arguably its own lifecycle |
| `newsletter_subscribers` | `email` | Separate consent with its own unsubscribe |
| `mobile_app_waitlist`, `palette_playbook_waitlist` | `email` | Separate signups |
| `sales`, `subscriptions` | `customer_email` | **Do not delete.** Financial records |

Recommended split, for Chris to confirm rather than for the implementer to assume:

- **Delete with the account:** `telegram_link_codes`, `telegram_account_links`. They are pure
  bindings to an identity that no longer exists and are useless once it is gone. The Telegram ones
  matter for more than tidiness: an account link left behind is an authorization record.
- **Anonymize rather than delete:** `vouchers.redeemed_by_user_id` (null it, keep the redemption so
  a code cannot be reused), and `feedback` (keep the message, clear name and email).
- **Leave alone, and say so in the policy:** `sales` and `subscriptions`, which are transaction
  records with their own retention basis; and `newsletter_subscribers`, `affiliate_applicants` and
  the two waitlists, which are separate opt-ins with their own exits.

The policy wording must describe whichever split is chosen. "We delete everything" is the easiest
sentence to write and the one most likely to be false.

`user_palettes` and `conversations` were checked and carry **no** user column at all, so neither is
in scope. Do not delete from them.

---

## 3. The resurrection race, and why the webhook alone is not enough

`requireAuth` and `optionalAuth` **lazily create the `users` row on any authenticated request**
(`middlewares/requireAuth.ts:37-86`, `middlewares/optionalAuth.ts:41-70`). Neither checks whether
the account was just deleted, so a request carrying a still-valid Clerk session JWT re-inserts the
row after the webhook has removed it. Clerk session tokens are short-lived, so the window is small,
but "small" is exactly what makes it survive a single manual test and reappear in production.

Two outcomes, both bad:

- If `clerkClient.users.getUser(userId)` still answers during Clerk's own propagation, the insert
  succeeds with an email and `insertedNew` is true, which fires the Loops **`account_created`**
  event (`requireAuth.ts:79-85`). That sends a *welcome email to somebody who has just deleted their
  account.*
- If Clerk has already 404'd, the `catch` branch inserts a minimal row anyway
  (`requireAuth.ts:71-74`). No email, but a bare orphan row, and the deletion claim is false again.

**Those two middlewares are the only writers.** A search for `insert(usersTable)` across the whole
of `artifacts/api-server/src` returns four hits and all four are in `requireAuth.ts` and
`optionalAuth.ts`. No route, service or other webhook creates a user row. So fixing these two files
closes the resurrection surface completely rather than partially, which is why this is worth doing
properly instead of guarding one endpoint at a time.

**The fix is small and belongs in the same change as the webhook.** In both middlewares, treat a
Clerk "user not found" as a definite answer: do not insert, and reject the request. Only fall back
to the minimal insert on a genuine transport or server failure, which is what that branch was
written for. Distinguish the two by the Clerk error status rather than by catching everything.

If a tombstone is preferred over relying on Clerk's answer, a `deleted_user_ids` table checked
before insert also closes it. That is more moving parts for the same result, so prefer the Clerk
404 check unless there is a reason not to.

---

## 4. Building the webhook

**Follow the Lemon Squeezy precedent exactly**, because it already solves the two things that are
easy to get wrong here. See `routes/lemonWebhook.ts:326-370` and its mount in `app.ts`.

1. **Mount before `express.json()`.** Signature verification needs the raw body.
   `lemonWebhookRouter` is mounted ahead of the JSON parser for this reason and the comment in
   `app.ts` says so. A Clerk webhook router must be mounted the same way, with
   `express.raw({ type: "*/*" })` on the route.
2. **Reject anything unsigned or invalid.** Clerk signs with Svix (`svix-id`, `svix-timestamp`,
   `svix-signature` headers, a `whsec_...` signing secret). Verify with the `svix` package or
   Clerk's own `verifyWebhook` helper, whichever the installed Clerk version provides. Missing
   secret returns 503, bad signature returns 401. Do not parse the body before verifying it.
3. **Be idempotent.** Svix retries, so a repeat of `user.deleted` for an already-deleted user must
   answer 200, not 500. Deleting a row that is already gone is naturally idempotent; the thing to
   get right is not treating "zero rows affected" as a failure.
4. **Return 500 only for real failures**, so retries happen when they should. A malformed payload is
   400 and should not be retried.
5. **Handle `user.deleted` and ignore the rest.** Answer 200 to unhandled event types so Clerk does
   not retry them forever. The user id arrives as `data.id`; confirm the payload shape against a
   test send from the Clerk dashboard rather than trusting this line.
6. **Do the deletes in one transaction**, so a partial delete cannot leave the account half-removed.

**Account-side dependency worth planning for:** per `CLAUDE.md`, the Clerk tenant is Replit-managed
and there is no standalone ColorSense Clerk account. Registering the webhook endpoint and reading
its signing secret needs that dashboard access. This cannot be finished from the repo alone.

---

## 5. Contracts that must not change

The shipped iOS app depends on both of these, and a build is already on TestFlight:

- **`GET /api/me`** response shape. Note it currently returns **404** when no row exists, and does
  not create one. Keep that.
- **`/api/saved-palettes`** in full: `GET`, `POST {name, colors}`, `DELETE /:id`.

Changing either breaks installed clients that cannot be updated on your schedule.

---

## 6. Acceptance criteria

Deletion is not "done" until all of these hold:

- [ ] Deleting from the **iOS app** removes the Clerk identity, the `users` row, every saved palette
      and saved color, and each additional table agreed in section 2.
- [ ] Deleting from the **website** does the same. Both paths go through Clerk, so both must be
      exercised rather than assumed equivalent.
- [ ] An unsigned or wrongly-signed webhook request is rejected, and the row survives.
- [ ] A replayed `user.deleted` returns 200 and changes nothing.
- [ ] **The resurrection race is closed:** immediately after deletion, an authenticated request made
      with the pre-deletion session token does **not** recreate the row and does **not** send a
      Loops `account_created` event.
- [ ] `GET /api/me` and every `/api/saved-palettes` route behave identically to before for a live
      account, verified against production.
- [ ] Evidence captured: the rows before and after, for a real test account, on production.

**No test may modify real customer data without explicit approval.** Use a purpose-made account.

---

## 7. What unblocks once this is proved

Only after the criteria above pass, and in this order:

1. Add the account-deletion paragraph to the privacy policy. It is deliberately absent today, see
   `docs/PRIVACY-AUDIT.md`. Word it to match the section 2 split, including whatever is retained.
2. Make the website's deletion copy and `DeleteAccountView`'s copy describe the same verified
   behavior. The in-app string is currently the stronger claim of the two.
3. Tick the blocker in `docs/APP-STORE-SUBMISSION.md` section 8c item 1 and section 9.

Until then, publish no deletion claim anywhere.
