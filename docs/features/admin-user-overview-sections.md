# Feature: Admin user overview sections and roles

## Goal

Make the admin user overview focus on store-owning members by default while keeping administrator accounts available in a separate section and making every listed account's role visible.

## Actors

- Admins and superadmins may view the overview.
- Active member, admin, and superadmin accounts may appear according to the selected section.
- Deactivated accounts remain excluded.

## Current behavior

`Admin::UsersController#index` lists all active users by default and optionally filters by one numeric role. The table shows name, email, and business, but not role. There is no section navigation.

## Desired behavior

The default section lists active ordinary users that have an associated business. An “Admins” tab lists active admin and superadmin accounts. Every row shows its role. Search, email-confirmation filtering, pagination, and access control continue to work within the selected section.

## Functional requirements

- REQ-001 — The default user overview must list only active role-0 users with an associated business.
- REQ-002 — The overview must provide an Admins tab that lists active role-1 and role-2 users.
- REQ-003 — The selected section must be preserved by search, confirmation filtering, reset, and pagination controls.
- REQ-004 — The table must display each listed user's role.
- REQ-005 — Invalid section input must safely fall back to the default store-user section.

## Acceptance criteria

- AC-001 — Given active store-owning members, members without a business, and administrators, when an admin opens the overview without section parameters, then only the store-owning members are listed.
- AC-002 — Given active admins and superadmins, when an admin selects the Admins tab, then both administrator roles are listed and ordinary users are absent.
- AC-003 — Given either selected tab, when the admin searches, filters by confirmation, resets filters, or changes pages, then the selected tab remains effective.
- AC-004 — Given any listed account, when its row is rendered, then its role name is visible in a Role column.
- AC-005 — Given an unsupported section parameter, when the overview is requested, then it renders the default section without an error.

## Authorization

Existing `Admin::BaseController#require_admin!` authorization is unchanged. The overview remains available only to authenticated admin or superadmin users.

## Data and persistence

None. The existing `users.role`, `users.deleted`, and `businesses.user_id` data are queried without schema or record changes.

## External side effects

None.

## Security and privacy

The change does not broaden access or expose new fields beyond the existing role already visible on the user detail screen. Section input is allowlisted server-side.

## UI states

- Store users is the visibly active default tab.
- Admins is visibly active when selected.
- Existing empty, search, confirmation-filter, pagination, and responsive table behavior remains.

## Edge cases

- A role-0 user without a persisted business is excluded from the default section.
- An admin or superadmin with a business is shown only in the Admins section.
- Deactivated accounts are excluded from both sections.
- Invalid section values select the store-user default.

## Compatibility / migration

No migration is needed. Existing direct role-filter URLs are no longer the primary navigation; the new allowlisted section parameter defines the overview grouping.

## Out of scope

- Changing role assignment or authorization rules.
- Showing deactivated accounts.
- Changing the separate admin stores overview.
- Adding a section for ordinary users without businesses.

## Evidence

- **CONFIRMED** — `app/controllers/admin/users_controller.rb` currently starts from `User.active.left_joins(:business)` and applies an optional numeric role filter.
- **CONFIRMED** — `app/views/admin/users/index.html.erb` currently omits a role column and provides no tabs.
- **CONFIRMED** — `app/models/user.rb` defines role 0 as User, role 1 as Admin, role 2 as Superadmin, and exposes `role_name` and `adminish?`.
- **CONFIRMED** — `Admin::BaseController#require_admin!` protects the overview.
- **ASSUMED** — “users with stores” means role-0 users with an associated `Business`; this is the smallest interpretation consistent with the existing domain model.
- **ASSUMED** — “the tab” means a separate Admins tab alongside the default store-user tab.

## Open questions

### BLOCKING

None.

### NON-BLOCKING

None; the two assumptions above use conservative defaults and do not alter stored data, permissions, or a sensitive workflow.

## Requirement-to-verification matrix

| Requirement | Acceptance criteria | Verification approach |
|---|---|---|
| REQ-001 | AC-001 | Controller integration test for default rows |
| REQ-002 | AC-002 | Controller integration test for admin-section rows |
| REQ-003 | AC-003 | Integration assertions for form, reset, and pagination parameters |
| REQ-004 | AC-004 | Rendered table assertions |
| REQ-005 | AC-005 | Invalid-parameter integration test |

## Final assessment

READY FOR PLANNING
