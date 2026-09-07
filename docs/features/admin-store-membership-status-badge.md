# Feature: Admin store membership status badge

## Goal

Make the current membership payment state on an admin store detail page immediately recognizable with a concise, color-coded badge.

## Actors

- Authenticated admins and superadmins viewing `/admin/stores/:id`.

## Current behavior

The Verwaltung section renders the current participation payment state as plain text. Pending and upgrade states use long explanatory labels.

## Desired behavior

Render one prominent badge for the current membership state: orange “Zahlung offen”, green “Bezahlt”, orange “Differenzzahlung offen”, or neutral “Nicht ausgewählt” when no current-year participation exists.

## Functional requirements

- REQ-001 — A pending current-year participation displays an orange “Zahlung offen” badge.
- REQ-002 — A fully paid current-year participation displays a green “Bezahlt” badge.
- REQ-003 — A paid participation with a payable pending upgrade displays an orange “Differenzzahlung offen” badge.
- REQ-004 — A store without a current-year participation displays a neutral “Nicht ausgewählt” badge.
- REQ-005 — The badge change is limited to the admin store detail membership status.

## Acceptance criteria

- AC-001 — Given a pending participation, when an admin views its store, then the membership status is an orange badge labeled exactly “Zahlung offen”.
- AC-002 — Given a paid participation without a pending upgrade, when an admin views its store, then the status is a green badge labeled exactly “Bezahlt”.
- AC-003 — Given a paid participation with a payable pending upgrade, when an admin views its store, then the status is an orange badge labeled exactly “Differenzzahlung offen”.
- AC-004 — Given no current-year participation, when an admin views the store, then the status is a neutral badge labeled exactly “Nicht ausgewählt”.

## Authorization

No change. Existing admin authorization remains authoritative.

## Data and persistence

None.

## External side effects

None.

## Security and privacy

No new data is exposed and no mutation is introduced.

## UI states

The badge includes text as well as color, so meaning does not depend on color alone. Existing detail layout and responsive behavior remain unchanged.

## Edge cases

A pending upgrade takes precedence over the paid base participation because an amount is currently due.

## Compatibility / migration

No migration or data backfill is required.

## Out of scope

- Changing payment state transitions.
- Changing labels on participation lists, user details, or member-facing pages.
- Changing the business approval status.

## Evidence

- **CONFIRMED** — `Participation` supports pending and paid payment states.
- **CONFIRMED** — `Participation#pending_upgrade` represents a payable outstanding difference after a base payment.
- **CONFIRMED** — The store detail already distinguishes no current participation.
- **INFERRED** — Neutral “Nicht ausgewählt” is the concise counterpart to the current “Noch nicht ausgewählt” text.

## Open questions

### BLOCKING

None.

### NON-BLOCKING

None.

## Requirement-to-verification matrix

| Requirement | Acceptance criteria | Verification approach |
|---|---|---|
| REQ-001 | AC-001 | Store controller integration assertion |
| REQ-002 | AC-002 | Store controller integration assertion |
| REQ-003 | AC-003 | Store controller integration assertion |
| REQ-004 | AC-004 | Store controller integration assertion |
| REQ-005 | AC-001–AC-004 | Scoped diff review and existing suite |

## Final assessment

READY FOR PLANNING
