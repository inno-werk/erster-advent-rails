# Implementation Plan: Client polish for September 2026

## Summary
Update the existing shared print-delivery partial, reorganize the existing Devise account-settings markup, and change the secondary daisyUI theme token. Preserve all controllers, persistence, authorization, and destructive behavior.

## Existing system findings
`PrintDistribution.current` already provides both dates and drives order-deadline enforcement. Account updating and deletion are already separate forms. The public-facing red accent consistently uses the `secondary` token; semantic failures use `error`.

## Proposed design
Render both annual dates from one `PrintDistribution.current` instance with semantic `<time>` elements and German display formats. Move the existing save button into the confirmation section, remove the now-unnecessary fixed account bottom bar, and wrap the deletion form in its own labelled warning card. Change only the secondary colour variable and related comments.

## Data changes
None.

## Authorization
No controller or route changes. Devise authentication, current-password verification, CSRF, and DELETE confirmation remain intact.

## Implementation steps

### Step 1 — Print-order copy
Files likely affected: `app/views/shared/_print_delivery.html.erb`, `test/controllers/participation_flow_test.rb`.

Changes: Render distribution weekday/date and order deadline with requested wording and missing-value fallbacks.

Verification: Focused integration test.

### Step 2 — Account action hierarchy
Files likely affected: `app/views/devise/registrations/edit.html.erb`, `test/controllers/participation_flow_test.rb`.

Changes: Co-locate save confirmation and action; isolate destructive deletion region.

Verification: Focused integration test and desktop/mobile browser inspection.

### Step 3 — Blue accent
Files likely affected: `app/assets/tailwind/application.css`.

Changes: Set the secondary theme token to the established brand blue and update misleading red-specific comments.

Verification: CSS build/test suite and browser inspection.

## Test plan
Run the focused participation-flow tests, JavaScript tests, full Rails suite, RuboCop, and Brakeman. Verify account update/deletion markup and configured/unconfigured delivery copy.

## Browser verification
Inspect account settings and a public page using secondary accents at desktop and mobile widths. Confirm the save/delete hierarchy and blue accent visually.

## Risks
Low: date wording could become stale if hard-coded; mitigated by continuing to render persisted annual configuration. Low: removing the fixed save bar could reduce visibility; mitigated by placing the primary action directly below its required password field.

## Assumptions
- **CONFIRMED** — Go-live and domain transfer are excluded.
- **INFERRED** — Semantic error/destructive red remains red.
- **ASSUMED** — Deployed annual dates will be entered through the existing admin configuration if not already present.

## Expected changed files
The two view partials/pages, the Tailwind theme source, relevant integration/model tests, the now-obsolete delivery-copy configuration, participation documentation, and these workflow artifacts.

## Definition of done
All acceptance criteria pass; focused and mandated checks pass; desktop/mobile browser verification is completed; the final diff contains no go-live, domain, or unrelated changes.

## Final assessment
READY FOR IMPLEMENTATION
