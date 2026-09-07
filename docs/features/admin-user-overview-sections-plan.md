# Implementation Plan: Admin user overview sections and roles

## Summary

Replace the user overview's numeric role filter with two allowlisted sections: store-owning ordinary users by default, and admins/superadmins on demand. Render those sections as tabs, add a role column, and carry the selected section through the shared list controls.

## Existing system findings

- `Admin::UsersController#index` already centralizes active-user search, confirmation filtering, eager loading, ordering, and pagination.
- `Admin::BaseController#list_choice` is the established allowlisting helper and safely supports a default.
- `admin/shared/_list.html.erb` owns search, reset, filter, count, and pagination controls but currently only preserves declared dialog filters.
- The users index already calls `User#role_name` on its detail screen, so no new presentation abstraction is needed.
- Existing user-list integration tests cover search/filter combinations and parameter preservation.

## Proposed design

The controller will parse `section` as `stores` or `admins`, defaulting to `stores`. The store section will constrain the existing joined scope to role 0 and require a business row. The admin section will constrain it to roles 1 and 2. Search and confirmation filtering remain composable.

The users view will render accessible section links styled as tabs and pass the current section to the shared list partial as fixed query parameters. The shared partial will include those fixed parameters in the search/filter form, reset URL, and pagination. The role dialog filter will be removed because section tabs now define the role grouping. A Role column will render `role_name`.

## Data changes

None.

## Authorization

No changes. `Admin::BaseController#require_admin!` continues to require an authenticated adminish user, while create/update remain superadmin-only where already enforced.

## Implementation steps

### Step 1 — Add section scoping

Files likely affected:

- `app/controllers/admin/users_controller.rb`

Changes:

- Allowlist and default the section parameter.
- Scope store users and administrator users according to the specification.

Why:

- Server-side scoping defines the actual overview contents independently of UI visibility.

Verification:

- Focused integration tests for default, admins, deactivated, and invalid-section behavior.

Dependencies:

- None.

### Step 2 — Render tabs, preserve section, and show roles

Files likely affected:

- `app/views/admin/users/index.html.erb`
- `app/views/admin/shared/_list.html.erb`

Changes:

- Add store-user and Admins tabs with an active state.
- Add the Role table column.
- Teach the shared list shell to preserve fixed query parameters through its controls.

Why:

- The selected section must survive all existing list interactions.

Verification:

- HTML assertions for tab destinations/active state, role cells, form hidden input, reset link, and pagination links.

Dependencies:

- Step 1.

### Step 3 — Update regression coverage

Files likely affected:

- `test/controllers/admin_participation_test.rb`

Changes:

- Update existing role-filter tests to use sections.
- Add exact row and role-column assertions for both sections and invalid input.
- Verify selected-section parameter preservation.

Why:

- The changed default is observable controller behavior and should be protected against regression.

Verification:

- Run the focused controller test, then the repository-required suite and static checks.

Dependencies:

- Steps 1 and 2.

## Test plan

- AC-001: fixture member and business appear by default; member without business and admin do not.
- AC-002: admin and a test superadmin appear under `section=admins`; role-0 users do not.
- AC-003: inspect section hidden field, reset URL, and paginated query.
- AC-004: assert Role heading and User/Admin/Superadmin values in the appropriate rows.
- AC-005: request an invalid section and assert the default active tab and rows.
- Regression: retain search escaping, confirmation filtering, page overflow, per-page sanitization, and admin authorization coverage.

## Browser verification

Exercise the user overview at desktop and narrow viewport widths, switching both tabs and using search/filter controls. Confirm the active tab, columns, row visibility, empty state, and horizontal table behavior. Automated request-level rendering is the primary evidence if a browser session is unavailable.

## Risks

- Shared-list parameter preservation could affect other admin lists. Mitigation: make the new local optional and empty by default, leaving all existing callers unchanged.
- Joined scopes can duplicate users if the association shape changes. Current `has_one :business` prevents multiplicity; no `distinct` is required.
- Removing direct numeric role filtering changes bookmarked URLs. Impact is limited to admin list presentation, and the requested tab behavior supersedes it.

## Assumptions

- **CONFIRMED** — Roles and the business association already exist and need no persistence work.
- **CONFIRMED** — Both Admin and Superadmin are administrator roles.
- **ASSUMED** — The default tab is store-owning role-0 users and the second tab combines Admin and Superadmin.

## Expected changed files

- `app/controllers/admin/users_controller.rb` — section scope.
- `app/views/admin/users/index.html.erb` — tabs and role column.
- `app/views/admin/shared/_list.html.erb` — fixed parameter preservation.
- `test/controllers/admin_participation_test.rb` — regression coverage.
- `docs/features/admin-user-overview-sections.md` — approved requirements.
- `docs/features/admin-user-overview-sections-plan.md` — implementation design.

## Definition of done

- All acceptance criteria pass focused integration assertions.
- `bin/rails test`, `bin/rubocop`, and `bin/brakeman --no-pager` pass.
- Relevant browser verification is completed where available.
- The complete diff preserves unrelated user changes and contains no temporary code.

## Final assessment

READY FOR IMPLEMENTATION
