# Implementation Plan: Admin business Excel export

## Summary

Add a dedicated admin export controller and view backed by one small export object that owns allowlisted status/sort normalization, the unpaginated query, shared row presentation, and XLSX generation. Link to it from the store list header.

## Existing system findings

- Admin routes and controllers are namespaced and guarded by `Admin::BaseController`.
- The shared admin list header accepts an `actions` local for top-right actions.
- Business statuses are Rails enum keys: `pending`, `confirmed`, `rejected`, and `deleted`.
- Addresses are free-form text; no structured street column exists.
- `rubyzip` is already present, but no XLSX writer is installed.
- `caxlsx` supports the project Ruby version and can produce the workbook directly without adding a Rails template adapter.

## Proposed design

Add singular `admin/business_export` routes for `show` and `download`. `Admin::BusinessExportsController` constructs `BusinessExport` from request parameters, applies private/no-index headers, renders the preview, or streams the workbook. `BusinessExport` exposes normalized selections, labels, a deterministic Active Record relation, shared headers/rows, and serialized XLSX bytes. All ordering SQL is fixed by internal constants; request values never enter SQL.

## Data changes

None. Add the `caxlsx` application dependency and its lockfile resolution only.

## Authorization

The new controller inherits the existing unauthenticated and non-admin redirects. The store list action is only rendered within the admin surface. Both preview and download are independently protected.

## Implementation steps

### Step 1 — Add XLSX support and export model

Files likely affected:
- `Gemfile`
- `Gemfile.lock`
- `app/services/business_export.rb`
- `test/services/business_export_test.rb`

Changes:
- Add `caxlsx` within a compatible version range.
- Implement allowlisted status/sort options, stable query order, shared row values, labels, and string-typed workbook cells.
- Test defaults, filters, sort choices, invalid input fallback, full row mapping, empty exports, and formula-like strings.

Why:
- One object prevents preview/download drift and keeps spreadsheet generation out of the controller.

Verification:
- Focused service tests and XLSX ZIP/XML inspection.

Dependencies:
- None.

### Step 2 — Add protected preview and download endpoints

Files likely affected:
- `config/routes.rb`
- `app/controllers/admin/business_exports_controller.rb`
- `test/controllers/admin_business_exports_test.rb`

Changes:
- Add GET preview and download routes.
- Render preview state and stream the `.xlsx` file with correct headers and a dated filename.
- Set private/no-index response headers on both actions.
- Test authentication, admin authorization, parameter fallback, content type, filename, and non-paginated inclusion.

Why:
- The new workflow is independent of list pagination and needs direct authorization coverage.

Verification:
- Focused controller integration tests.

Dependencies:
- Step 1.

### Step 3 — Build the preview UI and store-list action

Files likely affected:
- `app/views/admin/business_exports/show.html.erb`
- `app/views/admin/stores/index.html.erb`
- `app/views/layouts/admin.html.erb`
- `test/controllers/admin_business_exports_test.rb`

Changes:
- Add the compact top-right export action.
- Add accessible sort/status controls, count, horizontally scrollable preview table, empty state, and download button preserving selections.
- Keep the Geschäfte navigation item active on the export screen.

Why:
- Provides the requested review step and makes the effective export configuration visible before download.

Verification:
- HTML assertions and browser checks at desktop and narrow widths.

Dependencies:
- Step 2.

### Step 4 — Full verification and review

Files likely affected:
- No additional files expected.

Changes:
- Run focused and full checks, inspect the complete diff, exercise browser flows, and review each acceptance criterion.

Why:
- Confirms authorization, data parity, workbook integrity, and UI behavior.

Verification:
- `bin/rails test`, `bin/rubocop`, `bin/brakeman --no-pager`, relevant JavaScript/system tests, and browser verification.

Dependencies:
- Steps 1–3.

## Test plan

- Service: defaults, each sort, status filter, invalid fallback, stable ties, exact columns, categories/status labels, blank values, header-only workbook, formula-like strings.
- Controller: admin preview and download, all rows despite list page size, preserved controls, response headers, XLSX MIME/filename, ordinary-user and signed-out denial.
- Regression: existing admin store search/filter/sort/pagination remains unchanged.
- Security: fixed allowlists, no formula cells, private response headers, direct endpoint authorization.

## Browser verification

Use the admin store list and export preview as an admin. Verify navigation, default row order, alternate name order, each status selection, reset/all state, download action, empty state where feasible, horizontal scrolling, keyboard form use, and desktop/narrow layouts. Verify a downloaded workbook opens and matches the preview when the local environment permits.

## Risks

- Free-form addresses may not sort like structured postal addresses. Mitigation: disclose that the existing full address is the key and keep stable secondary ordering.
- Large exports are built in memory. Current business-directory scale and synchronous admin workflow make this acceptable; background generation is out of scope.
- Spreadsheet formula injection. Mitigation: explicitly set all imported business values to string cell types and test workbook XML contains no formulas.
- Contact-data leakage. Mitigation: inherit admin authorization and prevent caching/indexing.

## Assumptions

- **CONFIRMED** — The export is available from `/admin/stores`, opens a preview first, supports sorting and optional status filtering, and downloads Excel.
- **INFERRED** — Name ascending is the alternate sort based on existing admin-list behavior.
- **ASSUMED** — Full address ascending implements street sorting without inventing unreliable parsing.
- **ASSUMED** — No filter includes archived records as well as active statuses.

## Expected changed files

- `Gemfile`, `Gemfile.lock` — XLSX dependency.
- `config/routes.rb` — export routes.
- `app/controllers/admin/business_exports_controller.rb` — protected preview/download.
- `app/services/business_export.rb` — query, row mapping, workbook.
- `app/views/admin/business_exports/show.html.erb` — controls and preview.
- `app/views/admin/stores/index.html.erb` — entry action.
- `app/views/layouts/admin.html.erb` — active navigation state.
- `test/services/business_export_test.rb` — export behavior.
- `test/controllers/admin_business_exports_test.rb` — endpoint/UI/security behavior.
- Feature specification and this plan.

## Definition of done

- AC-001 through AC-010 have automated evidence.
- Preview/download parity and admin-only access are verified.
- Workbook opens as valid XLSX and contains no formula cells from business data.
- Full Rails tests, RuboCop, Brakeman, relevant JavaScript/system tests, browser flow, and complete diff review are performed or explicitly reported as not verified.

## Final assessment

READY FOR IMPLEMENTATION
