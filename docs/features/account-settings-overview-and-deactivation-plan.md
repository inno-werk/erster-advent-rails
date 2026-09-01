# Implementation Plan: Account settings overview and deactivation

## Summary
Keep Devise's account resource and routes, add dedicated authenticated personal/password actions, replace the combined edit form with a read-only overview, and override destruction with the existing `deleted` flag.

## Existing system findings
The current custom registrations controller only customizes layout, permitted sign-up fields, and redirect paths. Devise's inherited update requires a password for every change and inherited destroy physically deletes. `User.active` and admin soft-deactivation already establish the correct persistence convention, but login does not enforce it.

## Proposed design
Add explicit GET/PATCH routes for personal and password editors under `/users/edit`. Each controller action loads only `current_user` through Devise authentication. Personal updates use `update` with `name`, `phone`, and `email`; password updates use `update_with_password` with only password fields. Override destroy to flag, sign out, and redirect. Extend `User#active_for_authentication?` and its inactive message.

## Data changes
None. Reuse `users.deleted`.

## Authorization
Use Devise `authenticate_scope!` for every custom action. Never load a user from request parameters. Retain CSRF protection.

## Implementation steps

### Step 1 — Routes and controller boundaries
Add dedicated personal/password edit and update routes; implement allowlisted update actions and soft-deactivation.

### Step 2 — Authentication invariant
Make flagged users inactive for both member and admin login and provide localized failure copy.

### Step 3 — Read-only and editor views
Build the overview with established `data-grid` patterns, separate editor forms, and a flat warning section for deactivation.

### Step 4 — Regression coverage and documentation
Replace combined-form assertions with endpoint-isolation, password verification, soft-deactivation, data-retention, and login-denial tests. Update the durable workflow documentation.

## Test plan
Focused participation and session controller tests; complete Rails and JavaScript suites; changed-file RuboCop; Brakeman; route inspection; browser verification of overview and both editors at desktop/mobile sizes when a local authenticated session is available.

## Browser verification
Inspect `/users/edit`, personal edit, and password edit in the local app. Confirm there are no editable fields on overview, each link reaches the correct form, deactivation is visually separate, and responsive layout has no overflow. Do not execute deactivation during visual inspection.

## Risks
High security impact if parameter boundaries overlap; mitigated by separate actions and explicit strong parameters. High data-loss impact if Devise destroy remains reachable; mitigated by overriding the exact controller action and count-based tests. Medium compatibility impact for already flagged users; intended because deactivation must block login.

## Assumptions
- **CONFIRMED** — Preserve records and associations through the existing flag.
- **INFERRED** — Deactivated accounts must fail login.
- **ASSUMED** — No admin reactivation flow is part of this request.

## Expected changed files
Routes, registrations controller, user model, three registration views, account locale copy, focused controller/session tests, and account workflow documentation.

## Definition of done
All acceptance criteria pass; no destructive record deletion remains in self-service flow; authorization and parameter isolation are verified; mandated checks and diff review complete; no go-live work is performed.

## Final assessment
READY FOR IMPLEMENTATION
