# Feature: Immediate category changes with open difference, and admin category changes

## Goal

1. A member who upgrades a paid membership gets the new category immediately
   (e.g. can enter business details after leaving «Kein Eintrag»); the
   difference simply remains open until paid.
2. Administrators can set or change a member's participation category
   («Leistmitglied», «Nicht-Leistmitglied», «Kein Eintrag») for the active
   event year without impersonating the member. A member who already paid pays
   only the difference.

## Actors

- **Member** — changes their own category through the existing App flows;
  pays open amounts through the existing payment flows.
- **Admin / Superadmin** (`adminish?`) — changes a member's category from the
  admin user detail page; can confirm difference payments manually as today.
- **Excluded** — anonymous visitors and members must not reach the admin
  action.

## Current behavior

- Unpaid participations: category change re-snapshots the price. (CONFIRMED —
  `Participation#snapshot_category`)
- Paid participations: members may only upgrade `no_listing` → listed. A pending
  `ParticipationUpgrade` snapshots previous/new price and difference; the
  category is applied only when the difference is paid
  (`Participation#confirm_upgrade!`). Until then the member stays `no_listing`
  and `User#business_editing_allowed?` (`category != "no_listing"`) keeps
  «Mein Geschäft» and the setup business step locked. (CONFIRMED —
  `app/models/participation.rb`, `app/models/participation_upgrade.rb`,
  `app/models/user.rb`, `app/controllers/app/mystore_controller.rb`,
  `app/views/app/mystore/show.html.erb`)
- `docs/participation-and-print-materials.md` («Annual participation») documents
  this deferred application as intended; this feature deliberately replaces it.
  (CONFIRMED — developer request 2026-09-23)
- Difference payments run through `pending_upgrade` / `ParticipationUpgrade#payable?`
  in Stripe checkout and webhook fulfilment, the dummy payment, and the admin
  «Differenzzahlung bestätigen» action. (CONFIRMED)
- `one_pending_upgrade_per_participation` (partial unique index) allows one
  pending upgrade per participation. Legacy pending CHF 200 → 250 upgrades exist
  by design and are not payable. (CONFIRMED — `db/schema.rb`, docs)
- Admins can only toggle the initial payment status and confirm differences;
  the admin user page shows the membership read-only. (CONFIRMED)
- `StripeCheckoutSessionCreator#build_payment` reuses an unexpired active
  checkout for the same obligation without comparing amounts. (CONFIRMED)
- The admin list filter «Differenzzahlung offen» only recognises participations
  still in `no_listing`. (CONFIRMED — `Admin::ParticipationsController#index`)
- Public listing is independent of payment; only a current-year `no_listing`
  hides a confirmed business. (CONFIRMED — AGENTS.md invariant)

## Desired behavior

**Upgrade semantics (members and admins):** an upgrade of a paid participation
applies the new category and total price immediately. The participation stays
`paid` for what was already paid; a pending `ParticipationUpgrade` records the
open difference. Paying the difference only settles that record.

**Member self-service:** allowed changes are unchanged (`no_listing` → listed
after payment; any change before payment). After an upgrade the member can
immediately use features of the new category (business editing, listing
eligibility) and sees the difference as open.

**Admin change** on the user detail page, after confirmation:

| Situation | Result |
|---|---|
| No participation this year | Unpaid participation created at the category's price. |
| Unpaid participation | Category and price re-snapshotted; stays unpaid. |
| Paid, more expensive category (any direction) | Upgrade applied immediately; difference open. |
| Paid, cheaper category | Refused. |
| Same category | No-op. |
| A pending upgrade exists | Refused until settled. |

(CONFIRMED — developer decisions: create when missing; paid → pay difference
only, effective immediately; paid downgrade not allowed; member upgrades
effective immediately with difference open.)

## Functional requirements

### Upgrade semantics

- REQ-001 — Creating an upgrade on a paid participation, in one locked
  transaction, sets the participation's category, `amount_cents` (catalogue
  price) and `selected_at`, keeps `payment_status`, `paid_at`,
  `payment_provider`, `payment_reference`, and creates a pending
  `ParticipationUpgrade` with previous category/amount = state before, category/
  amount = new state, `difference_cents` = difference.
- REQ-002 — A pending upgrade is payable exactly while the participation is paid
  and still has that upgrade's category and `amount_cents`.
- REQ-003 — Paying a pending upgrade (verified Stripe webhook, dummy payment,
  admin confirmation) marks only the upgrade paid (with provider/reference as
  today); it does not change the participation's category or amount.
  Repeated confirmation remains a no-op.
- REQ-004 — Member-requested upgrades keep today's allowed targets
  (`no_listing` → `leist_member` / `non_leist_member`); admin upgrades allow
  any category with a higher catalogue price than the current `amount_cents`.
- REQ-005 — After a member upgrade from `no_listing`, «Mein Geschäft» and the
  setup business step are available immediately; the business is subject to
  the normal listing rules immediately.
- REQ-006 — A data migration applies every existing pending upgrade that is
  payable under the old rule (participation paid, category/amount equal to the
  upgrade's previous values, target is an allowed member upgrade): participation
  category/amount set to the upgrade's values. Other pending upgrades (e.g.
  legacy CHF 200 → 250) are left untouched and remain unpayable. The migration is
  idempotent and reversible (down restores previous category/amount for pending
  upgrades whose participation still matches the upgrade's values).

### Admin change

- REQ-007 — The admin user detail page offers a category selection with all
  `Participation::CATEGORIES` (title and price) for the active event year,
  preselecting the current category.
- REQ-008 — Saving for a user without an active-year participation creates one
  for that user and `EventConfiguration.year`, unpaid, at the catalogue price.
- REQ-009 — Saving a different category on an unpaid participation re-snapshots
  category, `amount_cents` and `selected_at`; it stays unpaid.
- REQ-010 — Saving a more expensive category on a paid participation performs
  REQ-001.
- REQ-011 — Saving a cheaper category on a paid participation is refused with a
  visible message and no data change.
- REQ-012 — Saving a different category is refused with a visible message and
  no data change while the participation has any pending upgrade.
- REQ-013 — Saving the currently stored category is a no-op.
- REQ-014 — Only `category` is accepted and must be a `Participation::CATEGORIES`
  key; submitted price, amount, difference, payment status, user, year or IDs
  are ignored. Invalid keys are rejected with a message.
- REQ-015 — The confirmation dialog states the consequence; for a paid
  participation it names the open difference.
- REQ-016 — After success the admin returns to the user detail page with a
  notice; category, status, current amount and open amount reflect the change.
- REQ-017 — Only the active event year is changed; past years never.

### Payments and presentation

- REQ-018 — On an unpaid re-price (member or admin), active (`pending`,
  `checkout_created`, `processing`) initial `StripePayment`s of that
  participation are marked `expired` locally.
- REQ-019 — Checkout never reuses an active checkout whose `amount_cents`
  differs from the amount currently due; a new attempt is created.
- REQ-020 — Texts that say the upgrade/listing is activated only after payment
  are updated: member membership, payment, dummy checkout and «Mein Geschäft»
  pages, and the admin «Differenzzahlung bestätigen» confirmation. Wording states
  the category is active and the difference is open.
- REQ-021 — The admin participation list filter treats a paid participation with
  a payable pending upgrade as «Differenzzahlung offen» and as open in «Zahlung
  offen», not «Vollständig bezahlt».
- REQ-022 — `docs/participation-and-print-materials.md` is updated to the new
  upgrade semantics and the admin category change.

## Acceptance criteria

- AC-001 — Given a paid `no_listing` member, when they upgrade to
  `leist_member`, then the participation is `leist_member` / 20 000 / `paid`
  immediately, one pending upgrade with difference 10 000 exists, and
  «Mein Geschäft» editing and the setup business step are accessible.
- AC-002 — Given AC-001's state, when the difference is paid via verified Stripe
  webhook (10 000 CHF), dummy payment, or admin confirmation, then the upgrade is
  `paid` and the participation is unchanged (`leist_member` / 20 000).
- AC-003 — Given AC-001's state, when the member starts Stripe checkout, then it
  is an upgrade payment for exactly 10 000.
- AC-004 — Given AC-001's state, then the member overview and payment page show
  «Leistmitglied» and an open difference of CHF 100.00 without saying
  activation waits for payment.
- AC-005 — Given a paid `leist_member` member, when they submit an upgrade to
  `non_leist_member` or submit price/payment fields, then no upgrade is created
  (member rules unchanged).
- AC-006 — Given an existing pending `no_listing` → `leist_member` upgrade on a
  paid `no_listing` participation, when the migration runs, then the
  participation is `leist_member` / 20 000 and the upgrade is payable; running it
  again changes nothing; a legacy pending 200 → 250 upgrade is unchanged.
- AC-007 — Given an admin on a member's detail page, then «Mitgliedschaft
  <Jahr>» shows a category select (title + CHF price) and a save button.
- AC-008 — Given no active-year participation, when the admin saves
  «Nicht-Leistmitglied», then one `non_leist_member` / 25 000 / `pending`
  participation exists for that member and year.
- AC-009 — Given an unpaid `leist_member` participation, when the admin saves
  `no_listing`, then it is `no_listing` / 10 000 / `pending`.
- AC-010 — Given a paid `leist_member` participation, when the admin saves
  `non_leist_member`, then it is `non_leist_member` / 25 000 / `paid` with
  unchanged `paid_at`/provider/reference and a pending upgrade of 5 000.
- AC-011 — Given a paid participation whose earlier upgrade is paid (total
  20 000), when the admin saves `non_leist_member`, then a new upgrade of 5 000
  is created.
- AC-012 — Given a paid `non_leist_member` participation, when the admin saves a
  cheaper category, then nothing changes and an error is shown.
- AC-013 — Given any pending upgrade, when the admin saves a different category,
  then nothing changes and an error is shown.
- AC-014 — Given a paid participation, when the admin saves the same category,
  then nothing changes and no upgrade is created.
- AC-015 — Given an unpaid participation with an active `checkout_created`
  initial Stripe payment, when the category changes (member or admin), then that
  Stripe payment is `expired`.
- AC-016 — Given an active unexpired checkout whose amount differs from the due
  amount, when checkout starts, then a new attempt with the current amount is
  created.
- AC-017 — Given an admin request with extra `amount_cents`, `difference_cents`,
  `payment_status`, `user_id` or `year`, then only the category is applied.
- AC-018 — Given an invalid category key, then nothing changes and an error is
  shown.
- AC-019 — Given a member or anonymous visitor, when they send the admin
  request, then they are denied and nothing changes.
- AC-020 — Given a paid participation, then the admin confirmation for a more
  expensive category names the difference amount.
- AC-021 — Given AC-010's state, then the admin list shows the participation
  under «Differenzzahlung offen» and «Zahlung offen», not «Vollständig bezahlt».
- AC-022 — Given only a previous-year participation, when the admin saves, then
  a new active-year participation is created and the old one is unchanged.

## Authorization

- Admin action: existing `Admin::BaseController` boundary (`adminish?`); target
  user from the route; participation resolved as `user.participations.for_year`,
  never by submitted ID.
- Member flows: unchanged `current_user` scoping.

## Data and persistence

- No schema change. One data migration (REQ-006).
- Existing constraints remain the backstop: valid category, payment-state
  consistency, unique `user_id, year`, one pending upgrade per participation,
  `amount_cents = previous_amount_cents + difference_cents`.
- A narrow, explicit model transition bypasses `protect_paid_snapshot` only for
  applying an upgrade, under the participation lock (user lock for creation).
- `mark_unpaid!` stays refused when upgrades exist.

## External side effects

- No email, no Stripe API call, no refund.
- Difference payments keep the upgrade obligation (`participation-upgrade:<id>`)
  and webhook verification; amount/currency/ownership checks unchanged.
- A Stripe session for an old amount still open in a browser remains payable at
  Stripe until expiry; if completed, the webhook rejects the mismatch and records
  a failed event for manual reconciliation. (ASSUMED acceptable.)
- Public listing follows the category immediately. A member leaving
  `no_listing` becomes publicly listed (if admin-confirmed) before paying the
  difference — consistent with «payment status does not affect listing».

## Security and privacy

- CSRF-protected forms; strong parameters permit only `category`.
- No IDOR; no sensitive data logged.
- Duplicate submissions: same category no-op; a second change is refused while
  an upgrade is pending; the unique index backs this.
- Only verified Stripe webhook, explicit dummy flow or admin confirmation can
  mark a difference paid.

## UI states

- Admin: select + save button in the membership aside (`admin-detail-section`,
  daisyUI `select`, `btn-sm`); cheaper options may be disabled for paid
  participations (server refuses regardless); while an upgrade is pending the
  form is replaced by a hint. `turbo_confirm`, success notice, refusal alert.
- Member: overview/payment show the new category plus open difference and
  «Differenz bezahlen»; «Mein Geschäft» unlocked.
- Phone width and keyboard operable.

## Edge cases

- Member never pays the difference: category stays applied, difference stays
  open and visible to admins (filter) — same as an unpaid membership.
- Concurrent webhook vs. change: participation lock serializes; stale amounts
  rejected by `payable?`.
- Legacy non-payable pending 200 → 250 upgrade: blocks further changes for that
  participation (existing unique index) — unchanged limitation.
- Deactivated user: admin change allowed (consistent with payment toggles).

## Compatibility / migration

- Data migration changes category/amount of participations with pending
  `no_listing` upgrades; their businesses may become publicly listed after
  deploy. Down migration restores them.
- Code rollback after deploy requires running the down migration first,
  otherwise new-style pending upgrades become unpayable.

## Out of scope

- Refunds, credits, downgrades of paid memberships, cancelling upgrades.
- Changing member self-service targets (e.g. member 200 → 250).
- Remote Stripe session expiry, member email notification.
- Admin change from store page or participation list; past years.

## Evidence

- `app/models/participation.rb`, `app/models/participation_upgrade.rb`,
  `app/models/user.rb`, `app/models/stripe_payment.rb` — CONFIRMED.
- `app/controllers/app/participations_controller.rb`,
  `app/controllers/app/mystore_controller.rb`,
  `app/controllers/app/setup/*`, `app/controllers/concerns/test_payment_processing.rb`,
  `app/controllers/admin/participations_controller.rb`,
  `app/controllers/admin/participation_upgrades_controller.rb` — CONFIRMED.
- `app/services/stripe_checkout_session_creator.rb`,
  `app/services/stripe_webhook_processor.rb` — CONFIRMED.
- Views: `app/views/app/participations/*`, `app/views/app/mystore/show.html.erb`,
  `app/views/app/test_payments/_checkout.html.erb`,
  `app/views/shared/_participation_upgrade.html.erb`,
  `app/views/admin/users/show.html.erb`, `app/views/admin/shared/_participations.html.erb`,
  `app/views/admin/stores/_payments.html.erb` — CONFIRMED.
- `db/schema.rb`, `docs/participation-and-print-materials.md` — CONFIRMED.
- Developer decisions 2026-09-23 — CONFIRMED.

## Open questions

### BLOCKING

None.

### NON-BLOCKING

- Remote Stripe session expiry — default: local expiry only.
- Member notification of admin changes — default: none.
- Redirect after a member upgrade — default: keep the existing redirect to the
  payment page (payment is offered, not required to continue).

## Requirement-to-verification matrix

| Requirement | Acceptance criteria | Verification approach |
|---|---|---|
| REQ-001, REQ-005 | AC-001 | Model + integration test + browser check |
| REQ-002, REQ-003 | AC-002, AC-003 | Model, webhook, dummy payment, admin confirm tests |
| REQ-004 | AC-005, AC-010, AC-011 | Model + integration tests |
| REQ-006 | AC-006 | Migration test |
| REQ-007, REQ-016 | AC-007 | Integration test + browser check |
| REQ-008, REQ-017 | AC-008, AC-022 | Integration test |
| REQ-009 | AC-009 | Integration test |
| REQ-010 | AC-010, AC-011 | Integration test |
| REQ-011 | AC-012 | Integration test |
| REQ-012 | AC-013 | Integration test |
| REQ-013 | AC-014 | Model test |
| REQ-014 | AC-017, AC-018 | Integration test |
| Authorization | AC-019 | Integration test |
| REQ-015 | AC-020 | Integration test |
| REQ-018 | AC-015 | Model/integration test |
| REQ-019 | AC-016 | Service test |
| REQ-020 | AC-004 | Integration test + browser check |
| REQ-021 | AC-021 | Integration test |
| REQ-022 | — | Diff review |

## Final assessment

READY FOR PLANNING
