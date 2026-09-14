# Implementation Plan: Admin print-product image removal and manual payment approval

## Summary

Add a transient `remove_image` form parameter to the existing print-product
editor. On a successful update, purge the attachment only when no replacement
upload was submitted. Add focused regression coverage for the already-present
admin user-page payment approval action.

## Existing system findings

`PrintProduct` uses `has_one_attached :image`; the controller currently permits
only upload and product fields. The shared admin payment partial is used by the
user and store detail pages and already posts to the locked participation and
upgrade transitions. No new payment abstraction is needed.

## Proposed design

The controller will extract and boolean-cast `remove_image` from strong
parameters, remove it from the attributes passed to Active Record, and purge
the attachment after a successful update when no replacement is present. The
view will render a labeled checkbox beside the current image. Tests will cover
rendering, successful removal, validation failure, replacement precedence, and
the user-page manual approval flow.

## Data changes

None.

## Authorization

`Admin::BaseController#require_admin!` protects the print-product and payment
controllers. The payment test will verify a normal member is redirected and
cannot change the participation.

## Implementation steps

### Step 1 — Add save-time image removal

Files likely affected:

- `app/controllers/admin/print_products_controller.rb`
- `app/views/admin/print_products/_form.html.erb`

Changes:

- Permit `remove_image` as a transient parameter.
- Purge only after a successful update and only when no replacement upload is
  present.
- Render a checkbox only for a persisted attachment.

Verification: focused admin integration tests.

### Step 2 — Add regression coverage for both workflows

Files likely affected:

- `test/controllers/admin_participation_test.rb`

Changes:

- Exercise image removal, failed-save retention, replacement precedence, and the
  payment approval button/action from the admin user page.

Verification: focused test file.

## Test plan

Run focused admin controller tests, then the full Rails test suite, RuboCop, and
Brakeman. Existing system/browser coverage is relevant only as a smoke check;
the interaction is a standard server-rendered form and can be verified through
the integration tests.

## Browser verification

If a browser session is available, verify the image checkbox and manual payment
button on a desktop and narrow viewport. Automated integration assertions cover
the server behavior and rendered controls.

## Risks

- Purging before validation would lose the existing image; mitigation: purge
  only after `update` returns true.
- A simultaneous replacement and removal could accidentally delete the new
  image; mitigation: replacement upload takes precedence.
- Manual payment could bypass model invariants; mitigation: reuse existing
  `mark_paid!` action and do not permit amount/date fields.

## Assumptions

- **CONFIRMED** — The existing manual approval behavior is the requested payment
  capability and should be preserved.
- **INFERRED** — A checkbox is the least surprising save-time removal UI because
  removal must be committed together with the edit form.
- **ASSUMED** — If both removal and upload are selected, replacement wins.

## Expected changed files

- `app/controllers/admin/print_products_controller.rb`
- `app/views/admin/print_products/_form.html.erb`
- `test/controllers/admin_participation_test.rb`
- The two feature documentation files created for this work.

## Definition of done

All acceptance criteria pass, required verification commands complete, the full
diff is reviewed, no unrelated changes are present, and no schema migration is
introduced.

## Final assessment

READY FOR IMPLEMENTATION
