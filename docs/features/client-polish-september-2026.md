# Feature: Client polish for print orders, account settings, and accent colour

## Goal
Apply the client's final pre-launch visual and copy corrections without starting the domain transfer or go-live.

## Actors
Signed-in members read print-order information and manage their own account. All website visitors see the public brand accent colour.

## Current behavior
The print-order delivery block shows the configured distribution date with a year and a generic delivery sentence, but not the configured order deadline. The account page places the current-password field inside the save form while the save action sits in a distant fixed bottom bar; the destructive action follows immediately below. The marketing secondary accent is hard-coded red (`#D03036`).

## Desired behavior
The print-order block states the configured weekday/distribution date and deadline using the client's wording. Account saving and deletion are visually and structurally distinct. The former red brand accent is blue, while semantic error and destructive states remain red.

## Functional requirements
- REQ-001 — Show the configured distribution date as «Die Printmaterialien werden am Samstag, 31.10., verteilt.» for 31 October 2026.
- REQ-002 — Show the configured deadline as «Bestellungen müssen bis am 5.10. eingehen.» for 5 October 2026.
- REQ-003 — Keep truthful fallback copy when either annual date has not been configured.
- REQ-004 — Place the account save action with the current-password confirmation fields.
- REQ-005 — Present account deletion as a separate destructive region with its existing confirmation and server behavior unchanged.
- REQ-006 — Replace the hard-coded red secondary brand accent with the established blue (`#52819C`).

## Acceptance criteria
- AC-001 — Given the 2026 dates are configured, when a member views the print-order delivery block, then both requested German sentences and machine-readable dates are present.
- AC-002 — Given one of the annual dates is blank, when the block renders, then it says that date or deadline is still to be announced.
- AC-003 — When a member views account settings, then the save button is inside the save-confirmation section and the delete control is inside a separately labelled destructive section.
- AC-004 — Account updates still require the current password, and deletion still uses DELETE with confirmation.
- AC-005 — Marketing elements using the secondary theme token render blue; error and destructive tokens remain unchanged.

## Authorization
Existing Devise authentication, current-user account scope, and deletion authorization remain unchanged.

## Data and persistence
None. Distribution and deadline values continue to come from the existing per-year `PrintDistribution` record and remain editable by administrators.

## External side effects
None.

## Security and privacy
Password handling, CSRF protection, confirmation behavior, and destructive account semantics remain unchanged.

## UI states
Configured and unconfigured dates are covered. Account actions must remain legible at desktop and mobile widths and keyboard accessible.

## Edge cases
The displayed dates must not diverge from the dates used to enforce order availability. Previous-year values must not leak into the active year.

## Compatibility / migration
No migration. Existing configured dates and account behavior are preserved.

## Out of scope
Domain transfer, deployment/go-live, email campaign delivery, changing annual dates in a deployed database, and recolouring semantic errors or destructive warnings.

## Evidence
- **CONFIRMED** — Client email supplies the exact copy, requests clearer account actions, blue instead of red accents, and later excludes go-live.
- **CONFIRMED** — `PrintDistribution.current` is the existing source for both annual dates and deadline enforcement.
- **CONFIRMED** — `app/views/devise/registrations/edit.html.erb` contains separate update and delete forms but visually separates the save button from its password field.
- **INFERRED** — “Akzentfarbe” refers to the hard-coded secondary brand token, not semantic error red, because the primary brand token is already blue and destructive/error red conveys status.

## Open questions
### BLOCKING
None.

### NON-BLOCKING
The production/staging date records may still need to be configured through the existing admin screen; default is to avoid embedding annual operational dates in application code.

## Requirement-to-verification matrix
| Requirement | Acceptance criteria | Verification approach |
|---|---|---|
| REQ-001–003 | AC-001–002 | Controller integration assertions for configured and blank dates |
| REQ-004–005 | AC-003–004 | Controller integration assertions plus responsive browser check |
| REQ-006 | AC-005 | Source/build inspection and browser check |

## Final assessment
READY FOR PLANNING
