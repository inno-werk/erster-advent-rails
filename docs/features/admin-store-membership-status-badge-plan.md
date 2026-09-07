# Implementation Plan: Admin store membership status badge

## Summary

Add a store-specific membership status badge partial and render it through the existing admin detail-field component. Cover every current domain state with exact label and color assertions.

## Existing system findings

- `admin/stores/show` renders membership status through `admin/shared/detail_field`.
- Existing business status badges establish the daisyUI `badge-soft` convention and pair icons with textual labels.
- The shared `participation_payment_label` is used by other admin/member views, so changing it would unnecessarily broaden scope.
- Existing store detail tests already construct and exercise no-participation, pending, paid, and pending-upgrade states.

## Proposed design

A new `admin/stores/_membership_status_badge` partial will accept the current participation. It will prioritize a pending upgrade, then paid, then pending, with nil rendered neutrally. The store detail will pass the rendered badge as `content` to the existing detail field.

## Data changes

None.

## Authorization

None. The existing `Admin::StoresController` boundary remains unchanged.

## Implementation steps

### Step 1 — Add and render the badge

Files likely affected:

- `app/views/admin/stores/_membership_status_badge.html.erb`
- `app/views/admin/stores/show.html.erb`

Changes:

- Map current domain states to concise labels, semantic colors, and icons.
- Render the partial in the Mitgliedschaftsstatus detail field.

Verification:

- Rendered integration assertions for each state.

### Step 2 — Update store detail regression tests

Files likely affected:

- `test/controllers/admin_participation_test.rb`

Changes:

- Replace long plain-text expectations with exact badge label/color expectations for nil, pending, paid, and pending-upgrade states.

Verification:

- Focused controller suite, full Rails suite, RuboCop, and Brakeman.

## Test plan

- Assert `badge-warning` and “Zahlung offen” for pending.
- Assert `badge-success` and “Bezahlt” for paid.
- Assert `badge-warning` and “Differenzzahlung offen” for a pending upgrade.
- Assert a neutral badge and “Nicht ausgewählt” for nil.
- Retain authorization and store approval behavior coverage.

## Browser verification

Visually inspect the Verwaltung section at desktop and narrow widths if an authenticated local admin session is available. Request-level rendered HTML tests remain the fallback when login blocks browser automation.

## Risks

- Color alone could be inaccessible. Mitigation: every badge has an exact textual label and a matching icon.
- Reusing the global payment label would change other pages. Mitigation: use a store-specific partial.

## Assumptions

- **CONFIRMED** — Pending upgrade should be shown as outstanding even though the base participation is paid.
- **INFERRED** — Neutral gray is appropriate for the absence of a selection.

## Expected changed files

- `app/views/admin/stores/_membership_status_badge.html.erb`
- `app/views/admin/stores/show.html.erb`
- `test/controllers/admin_participation_test.rb`
- This specification and plan.

## Definition of done

All four labels/colors are covered, the feature tests pass, required repository checks are run, and the final diff contains no unrelated changes.

## Final assessment

READY FOR IMPLEMENTATION
