# Feature: Account settings overview and deactivation

## Goal
Make account settings a read-only overview with explicit editors for contact details and password, and preserve all account data when a member deactivates the account.

## Actors
Authenticated users view and edit their own account. Deactivated users must be excluded from authentication and public business visibility. Administrators retain the existing account audit data.

## Current behavior
`GET /users/edit` is one combined form. Every update uses Devise `update_with_password`, and `DELETE /users` physically destroys the user and dependent records. The database already has a non-null `users.deleted` flag used by admin deactivation and public business visibility, but `User#active_for_authentication?` does not yet reject flagged users.

## Desired behavior
The account landing page is read-only. Personal details and password have separate edit pages and update endpoints. Personal details do not require a password; password changes require the current password. Self-service deletion sets `deleted` to true, signs the user out, preserves related data, and prevents subsequent authentication.

## Functional requirements
- REQ-001 — `GET /users/edit` displays name, phone, email, password status, and account-deactivation guidance without editable account fields.
- REQ-002 — Personal details have their own editor and accept only name, phone, and email without current-password verification.
- REQ-003 — Email changes retain Devise reconfirmation behavior.
- REQ-004 — Password changes have their own editor and require current password, password, and password confirmation.
- REQ-005 — Parameters for one editor cannot mutate fields owned by the other editor or the user role.
- REQ-006 — Self-service account deletion sets `users.deleted` and does not destroy the user or dependent records.
- REQ-007 — Successful deactivation signs out the current session and direct future login is rejected.
- REQ-008 — The deactivation control is a separate warning section, not a card mixed with editable account fields.

## Acceptance criteria
- AC-001 — When an authenticated user opens account settings, then the page contains no personal/password inputs and links to both dedicated editors.
- AC-002 — When valid personal details are submitted without a current password, then they are saved; an email change remains pending confirmation.
- AC-003 — When password data is submitted with a wrong current password, then the password is unchanged and validation renders on the password editor.
- AC-004 — When password data is submitted with the correct current password and matching confirmation, then the password changes and the session remains valid.
- AC-005 — When extra password or role parameters are sent to the personal endpoint, then neither password nor role changes; the reverse applies to personal fields on the password endpoint.
- AC-006 — When the user confirms deactivation, then `User.count` and related record counts are unchanged, `deleted` is true, and protected pages require login.
- AC-007 — When a deactivated user submits correct credentials, then authentication fails with a deactivated-account message.

## Authorization
All overview, personal, password, and deactivation actions require the current Devise user. No user ID is accepted; actions operate only on `current_user`.

## Data and persistence
No migration. Reuse the existing non-null boolean `users.deleted`. Associations and historical annual/payment/order records remain unchanged.

## External side effects
Changing email can send the existing Devise reconfirmation email according to `PROD_SEND`. Deactivation sends no email and clears the local session.

## Security and privacy
The personal endpoint uses an explicit allowlist and cannot update password or role. The password endpoint uses `update_with_password` with an explicit allowlist. CSRF remains enabled. Deactivated accounts fail Devise active-authentication checks.

## UI states
Read-only overview, pending email reconfirmation, personal validation failure, password verification/confirmation failure, and destructive warning/deactivation confirmation are covered. Pages retain the app layout and responsive established section/data-grid patterns.

## Edge cases
Repeated deactivation is prevented by authentication after the first request. Existing sessions on other devices are not proactively enumerated or revoked; subsequent fresh authentication is rejected. Admin reactivation UI is out of scope.

## Compatibility / migration
Existing users remain active because `deleted` defaults to false. Existing admin-deactivated users become consistently unable to authenticate directly.

## Out of scope
Physical deletion, anonymization, retention-policy changes, admin reactivation, domain transfer, and go-live.

## Evidence
- **CONFIRMED** — User requested a read-only account page, per-section editors, password-free personal changes, old-password verification for password changes, a separate delete warning, and flag-only deletion.
- **CONFIRMED** — `users.deleted`, `User.active`, admin soft-deactivation, and public visibility filtering already exist.
- **INFERRED** — A flagged account must be unable to authenticate because the existing admin UI describes the flag as deactivation.
- **ASSUMED** — Self-deactivation remains available to every authenticated role, matching the current Devise delete endpoint.

## Open questions
### BLOCKING
None.

### NON-BLOCKING
Cross-device session revocation is not currently supported; conservative scope is to sign out the initiating session and block future authentication.

## Requirement-to-verification matrix
| Requirement | Acceptance criteria | Verification approach |
|---|---|---|
| REQ-001, REQ-008 | AC-001 | Integration assertions and browser inspection |
| REQ-002–005 | AC-002–005 | Integration tests with valid, invalid, and injected parameters |
| REQ-006–007 | AC-006–007 | Integration/model authentication tests with count and session assertions |

## Final assessment
READY FOR PLANNING
