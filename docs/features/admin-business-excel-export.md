# Feature: Admin business Excel export

## Goal

Allow administrators to review and download the complete business directory as an Excel workbook, with deterministic ordering and an optional approval-status filter.

## Actors

- Admin and superadmin users configure, preview, and download the export.
- Ordinary members and unauthenticated visitors must not access the preview or workbook.

## Current behavior

The admin business list at `/admin/stores` supports search, status filtering, name sorting, and pagination, but has no spreadsheet export. Business information is stored in `businesses` and the account email belongs to the associated `user`.

## Desired behavior

The business list offers a compact Excel-export action. It opens a dedicated admin view containing export controls and a table preview. The preview and downloaded `.xlsx` file use the same complete, unpaginated data set, ordering, status filter, columns, and human-readable status labels.

## Functional requirements

- REQ-001 — The admin store list provides a top-right action linking to the export preview.
- REQ-002 — The export preview defaults to all business statuses and address ascending.
- REQ-003 — An admin can sort by address ascending or business name ascending.
- REQ-004 — An admin can optionally filter to exactly one valid business status: pending, confirmed, rejected, or deleted.
- REQ-005 — Missing or invalid filter/sort parameters fall back safely to the defaults and never become SQL fragments.
- REQ-006 — The preview displays the complete matching set without list pagination.
- REQ-007 — Preview and workbook contain, in the same order: business name, address, categories, status, contact person, phone, business email, account email, billing address, and website.
- REQ-008 — Categories are represented as a comma-separated value and statuses use the German admin labels.
- REQ-009 — The workbook is a valid `.xlsx` download with a dated, filesystem-safe filename and one worksheet.
- REQ-010 — Workbook cells containing user-managed text are emitted as strings, not executable formulas.
- REQ-011 — Preview and download responses are private and excluded from search indexing.

## Acceptance criteria

- AC-001 — Given an admin on `/admin/stores`, when the page renders, then a compact top-right “Excel-Export” action links to the export preview.
- AC-002 — Given businesses with differing addresses and statuses, when an admin opens the preview without parameters, then all statuses are present and rows are ordered by address, then business name, then ID.
- AC-003 — Given the same businesses, when `sort=name_asc` is selected, then rows are ordered by business name, then address, then ID.
- AC-004 — Given `status=confirmed`, when the preview or download is requested, then only confirmed businesses are included.
- AC-005 — Given an invalid status or sort value, when the preview or download is requested, then all statuses and address ordering are used.
- AC-006 — Given more rows than the admin list page size, when the export is previewed or downloaded, then every matching row is included.
- AC-007 — Given matching rows, when the workbook is downloaded, then its headers, row values, order, and status/category formatting match the preview.
- AC-008 — Given user-managed text beginning with `=`, `+`, `-`, or `@`, when exported, then it remains text and is not represented as an Excel formula.
- AC-009 — Given an ordinary member or unauthenticated visitor, when either export endpoint is requested directly, then the existing admin authorization redirects them without exposing business data.
- AC-010 — Given no matching businesses, when the preview renders, then it shows an empty state and the download remains a valid header-only workbook.

## Authorization

Both endpoints inherit `Admin::BaseController#require_admin!`. No record IDs are accepted, so there is no per-record ownership scope or IDOR surface.

## Data and persistence

None. The export reads existing `Business` and associated `User` rows. It does not mutate records or persist generated files.

## External side effects

None. The workbook is generated synchronously in memory and returned to the requesting admin.

## Security and privacy

The export contains administrative contact data and must remain admin-only. Responses use `Cache-Control: no-store, private` and `X-Robots-Tag: noindex, nofollow`. Sort and status values are allowlisted. Workbook data cells are explicitly typed as strings to prevent formula interpretation.

## UI states

- Normal: controls, row count, preview table, and download action.
- Empty: controls remain usable, a “no businesses” message is shown, and the workbook contains headers only.
- Permission denied: existing admin redirects apply.
- Responsive: the wide preview table scrolls horizontally; actions wrap on narrow screens.

## Edge cases

- Blank optional business fields are exported as empty strings.
- Duplicate names or addresses use stable secondary keys and ID as the final tie-breaker.
- Archived businesses are included by default because “no filtering” is explicitly requested; choosing another status limits the set.
- Newlines in addresses remain in the cell and preview naturally wraps them.

## Compatibility / migration

No migration is required. The implementation adds a server-side XLSX generation dependency compatible with the current Ruby/Rails versions and existing `rubyzip` constraint.

## Out of scope

- Arbitrary column selection, descending sorts, category/search filters, background generation, scheduled exports, and import.
- Splitting the free-form address into separately persisted street, house number, postal code, or town fields.

## Evidence

- **CONFIRMED** — `app/controllers/admin/stores_controller.rb` and `app/views/admin/stores/index.html.erb` implement the existing paginated admin list.
- **CONFIRMED** — `app/controllers/admin/base_controller.rb` enforces `adminish?` and provides allowlisted list choices.
- **CONFIRMED** — `db/schema.rb` defines business contact, address, category, and status fields; `Business` belongs to `User`.
- **CONFIRMED** — The request requires Excel, a top-right action, a dedicated preview, sorting led by street/address, another sort, and an optional status filter disabled by default.
- **INFERRED** — Business-name ascending is the most useful alternative because the existing list already offers name ordering.
- **ASSUMED** — “Street” means the existing free-form `businesses.address` value because there are no structured street columns.
- **ASSUMED** — The listed contact/admin fields form the smallest useful directory export; descriptions, images, social-media fields, and payment data are excluded.

## Open questions

### BLOCKING

None.

### NON-BLOCKING

- Whether admins later need structured street-number sorting. Default: sort the existing full address and avoid a data migration.
- Whether additional export columns or descending sorts are useful. Default: keep the first version focused and extend it from usage feedback.

## Requirement-to-verification matrix

| Requirement | Acceptance criteria | Verification approach |
|---|---|---|
| REQ-001 | AC-001 | Controller/view integration test and browser check |
| REQ-002–REQ-006 | AC-002–AC-006 | Export query/service and controller tests |
| REQ-007–REQ-010 | AC-007, AC-008, AC-010 | Workbook service tests inspecting XLSX package XML and controller download test |
| REQ-011 | AC-009 | Authorization and response-header integration tests |

## Final assessment

READY FOR PLANNING
