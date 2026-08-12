# Products, Orders, Payments & CMS — Technical Plan

Status: draft, pending customer sign-off on the open questions below.
Scope: everything beyond the existing store-registration flow (registration → admin approval), which is already implemented.

## 1. Current state of the codebase

The schema and routes already anticipate most of this work, but only as scaffolding:

| Area | Model | Routes/controllers | Views | Gap |
|---|---|---|---|---|
| Products | `Product` exists, `belongs_to :user, optional: true` | `Admin::ProductsController#index`, `App::ProductsController#index` | index-only, no forms | no create/edit/destroy anywhere; ownership model wrong for the new flow |
| Orders | `Order` exists, `belongs_to :product`, `belongs_to :customer` (a `User`) | `Admin::OrdersController#index`, `App::MyordersController#index` | index-only | no `status` or `paid` column at all; no store-facing order creation |
| Payments | `Payment` exists: `payment_image` (required attachment), `is_verified` string state | `Admin::TransactionsController#index`, `Admin::TransactionRequestsController#index` (filters pending), `App::TransactionsController#index` | index-only | `Payment belongs_to :user` (1:1), not linked to `Order`; looks built for a different original purpose (see §4) |
| Invoices | — | `Admin::InvoicesController#show` (stub) | stub | nothing generates a real invoice yet |
| CMS | `CmsBlock`: `page`, `position`, `block_type` enum (`image_block`/`content_block`/`qa_block`), rich text `title`/`content`, `has_many_attached :images` | `Admin::CmsController#edit/#update` (both empty) | none | frontpage view needs to be checked — may still render static content instead of `CmsBlock` records |

Nothing here requires ripping anything out — we're building forward on top of an already-sensible shape.

## 2. Products: host-managed catalog

- Remove store ownership of products. `Product#user_id` currently models "the store that owns this product" — that's no longer correct once only the host manages the catalog.
  - Migration: drop `user_id` from `products` (or keep it as `created_by_admin_id`, always an admin/superadmin `User`, if we want an audit trail of who created what).
  - Model: drop `belongs_to :user`, or repoint it at admin-only with a validation.
- `Admin::ProductsController` gets `new/create/edit/update/destroy`.
- `App::ProductsController#index` becomes a pure read-only catalog for stores to browse (already routed, view already exists as a stub).

## 3. Orders: stores order from the host

- `Order.customer` (a `User`) already represents the ordering store — no schema change needed there.
- Add to `orders`:
  - `status` — enum, matching the German states the admin already thinks in: `erstellt → bezahlt → versendet` (proposal below assumes payment happens before shipping; confirm sequencing with customer, see open question §6).
  - Ordering flow: `App::ProductsController` (or a new `App::OrdersController`) needs a `create` action building an `Order` for `current_user`.
- `Admin::OrdersController` gets `show` + a state-change action, following the existing pattern already used for store approval (`Admin::StoresController#confirm`) — i.e. `PATCH /admin/orders/:id/status` rather than a generic `update`.

## 4. Payments: linking to orders

The existing `Payment` model (`payment_session_id`, `plan`, `customer_email`, 1:1 with `User`) looks like it was built for a Stripe Checkout flow tied to store registration/subscription, not per-order payment — worth confirming with whoever built it before reusing it as-is, in case it's still needed for that original purpose.

Proposed for order payments:
- New `belongs_to :order` on `Payment` (or a fresh model if the existing one turns out to still be needed for registration fees — TBD, see open question §6).
- Formalize `is_verified` into a real Rails enum: `pending / approved / rejected` (currently a loosely validated string with inconsistent casing — `"Pending"` vs `"pending"`).
- `Admin::TransactionRequestsController` (already filters pending payments) becomes the approval queue; approving/rejecting flips the order's `status` accordingly.

## 5. Payment verification — three options compared

| Option | Build effort | What's already there | Trade-off |
|---|---|---|---|
| **Screenshot upload** | Low — mostly done | `Payment.payment_image` attachment, `TransactionRequestsController` review queue | Fully manual, doesn't scale, no reconciliation, easy to submit a fake/wrong screenshot |
| **Bank statement upload + auto-matching** | High — new parser (format depends on their bank: CAMT.053 XML / MT940 / bank-specific CSV), new `Transaction` model, matching logic (amount + reference text, not amount alone — collisions are likely with amount-only matching) | Nothing | Real reconciliation, scales, but meaningful engineering investment; only worth it past a certain order volume |
| **Hosted checkout (Stripe/PayPal)** | Medium — webhook-driven, no manual review at all | `payment_session_id` column already exists on `Payment`, suggesting Stripe was considered before | Removes the approval problem entirely; requires the customer to accept card/instant-transfer fees and a payment provider account |

Recommendation: ship the screenshot flow first since it's ~80% built, treat bank-statement reconciliation as a later optimization once real order volume is known, and rule the hosted-checkout option in or out early since it changes several downstream decisions (whether "approval" is even a workflow we need to build).

Independent of which option is chosen: an invoice email (PDF via ActionMailer) can be sent at order time and/or at payment-confirmation time — `Admin::InvoicesController#show` already exists as a stub for this.

## 6. Open questions for the customer

See the accompanying German concept document, `docs/konzept-bestellprozess.md`, for the proposed flow and the few points still open with the customer.
