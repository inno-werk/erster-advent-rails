# Feature: Admin print-product image removal and manual payment approval

## Goal

Allow administrators to remove an existing print-product image while saving the
other product fields, and make the existing manual payment approval workflow on
an admin user's page explicit and regression-tested.

## Actors

Authenticated admin and superadmin users may use the admin print-product editor
and user detail pages. Non-admin users must be denied by the existing admin
boundary.

## Current behavior

- `Admin::PrintProductsController` permits image upload/replacement but has no
  save-time image removal control.
- The user detail page renders the shared payment history partial. It already
  offers an admin-only “Als bezahlt markieren” action for a changeable initial
  participation payment and a confirmation action for an eligible upgrade.
- `Admin::ParticipationsController` calls the model's locked payment transition;
  submitted amount, paid date, and ownership are not trusted.

## Desired behavior

An administrator can select removal of an existing print-product image and save
the form. The image is removed only after the product update succeeds. An image
uploaded in the same submission takes precedence over removal. Manual payment
approval remains available from the user's payment history and continues to use
the existing server-side transition.

## Functional requirements

- REQ-001 — The admin print-product edit form exposes an image-removal control
  only when the product has a persisted image.
- REQ-002 — A successful update with image removal selected purges the existing
  image and preserves the other submitted product changes.
- REQ-003 — A failed product update does not purge the existing image.
- REQ-004 — An image uploaded in the same submission replaces the existing image
  and takes precedence over the removal control.
- REQ-005 — An authenticated admin can manually mark an eligible initial
  participation payment as paid from the admin user's page.
- REQ-006 — Manual payment approval uses the existing locked model transition,
  records the current payment time, and does not initiate an online payment.
- REQ-007 — Non-admin users cannot invoke either admin workflow.

## Acceptance criteria

- AC-001 — Given a persisted print-product image, when an admin opens the edit
  form, then an image-removal checkbox is present.
- AC-002 — Given a valid edit with removal selected, when the admin saves, then
  the product changes persist and the image is no longer attached.
- AC-003 — Given an invalid edit with removal selected, when the admin saves,
  then the edit form is returned with errors and the image remains attached.
- AC-004 — Given a valid replacement upload and removal selected, when the admin
  saves, then the replacement remains attached.
- AC-005 — Given an eligible pending initial payment, when an admin views the
  user's page, then a manual approval action is rendered and submitting it marks
  the participation paid without accepting client-supplied payment data.
- AC-006 — Given a normal member, when they request either admin action, then
  the request is denied and the payment/image state is unchanged.

## Authorization

The existing `Admin::BaseController#require_admin!` remains the server-side
boundary for both workflows. Payment records are loaded through their submitted
record IDs but their user redirect is derived from the persisted association;
no owner or payment state is accepted from the browser.

## Data and persistence

No migration is required. Active Storage purges the print-product attachment
after a successful product update. Existing payment status, paid timestamp,
ownership, and amount invariants remain model-controlled.

## External side effects

Image purge is performed only after a successful update. Manual approval does
not call Stripe or send email.

## Security and privacy

CSRF protection, strong parameters, Active Storage ownership through the admin
record lookup, and the existing payment authorization remain unchanged.

## UI states

The removal control is hidden when no persisted image exists. Validation errors
retain the edit form and existing image. The existing confirmation prompt and
success redirect remain in place for manual approval.

## Edge cases

If removal and a replacement upload are both submitted, the replacement wins.
If validation fails, no attachment is purged.

## Compatibility / migration

No schema or data migration. Existing print-product uploads and payment records
remain compatible.

## Out of scope

Changing Stripe webhook semantics, adding payment methods, editing payment
amounts, or adding print-product deletion.

## Evidence

- **CONFIRMED** — `app/controllers/admin/print_products_controller.rb` permits
  image upload but has no removal parameter.
- **CONFIRMED** — `app/views/admin/print_products/_form.html.erb` renders the
  existing image and upload field.
- **CONFIRMED** — `app/views/admin/stores/_payments.html.erb` renders manual
  initial-payment and upgrade-payment actions on the user detail page.
- **CONFIRMED** — `app/controllers/admin/participations_controller.rb` uses
  `Participation#mark_paid!`, which applies a locked server-side transition.
- **CONFIRMED** — Existing controller tests cover admin authorization and
  payment status transitions.

## Open questions

### BLOCKING

None.

### NON-BLOCKING

None.

## Requirement-to-verification matrix

| Requirement | Acceptance criteria | Verification approach |
|---|---|---|
| REQ-001 | AC-001 | Admin controller view test |
| REQ-002 | AC-002 | Admin integration test and attachment assertion |
| REQ-003 | AC-003 | Invalid update integration test |
| REQ-004 | AC-004 | Replacement/removal integration test |
| REQ-005–006 | AC-005 | User-page render and admin submit integration test |
| REQ-007 | AC-006 | Existing and focused authorization tests |

## Final assessment

READY FOR PLANNING
