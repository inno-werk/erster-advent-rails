# Implementation Plan: Participation invoices with Swiss QR bill

## Summary

Admin billing page for the active year, singleton bank settings, auditable
invoice runs with one `ParticipationInvoice` per recipient, a Prawn PDF with a
vector QR bill (`rqrcode`), a mailer, and a per-invoice delivery job.

## Existing system findings

- List page `admin/participations/index` uses `admin/shared/list` with an
  `actions` slot in the title bar → button goes there.
- `admin/print_order_exports/letters` is the pattern for text + PDF iframe
  preview + bottom bar; `PrintOrderPdf` is the Prawn pattern (`LayoutError`,
  no overflow). `SiteSetting.current` is the singleton pattern.
- `EmailDelivery.enabled?` / `before_deliver` is the mail gate pattern.

## Proposed design

- `InvoiceSetting` (model, `current`), `qr_creditor`/`snapshot`, IBAN and
  charset validation.
- `ParticipationInvoice.recipients(year)` builds the due set;
  `ParticipationInvoice.digest(set)` fingerprints ids + amounts + kinds.
- `InvoiceRun.start!(…)` validates settings, recipients, addresses, PROD_SEND,
  digest, then in one transaction creates the run and invoices; jobs are
  enqueued after commit. Unique idempotency key → `RecordNotUnique` returns the
  existing run.
- `ParticipationInvoiceDeliveryJob`: lock → claim `queued → sending` after
  re-checking PROD_SEND and `still_due?` → render PDF → `deliver_now` →
  `sent`; exceptions → `failed` with message. No automatic retries.
- `SwissQrBill` (payload + validation) and `ParticipationInvoicePdf` (layout).
- `ParticipationInvoiceMailer#invoice`.
- Controllers: `Admin::InvoiceRunsController` (new, create, show, preview,
  retry), `Admin::InvoiceSettingsController` (edit, update; `return_to` limited to the billing page).
- Development SMTP from `SMTP_*` env when `SMTP_ADDRESS` is set (Ethereal).

## Data changes

Three additive tables (see spec). Rollback drops them.

## Authorization

`Admin::BaseController#require_admin!` on every action; preview participation
looked up inside the recipient set; run/invoice retry scoped to the run.

## Implementation steps

1. Gem, fonts, migrations, models + model tests.
2. `SwissQrBill` + tests against the decoded example payload.
3. `ParticipationInvoicePdf` + visual comparison with the example.
4. Mailer, job + tests.
5. Controllers, routes, views, menu entry + integration tests.
6. Dev SMTP config, docs, browser verification with Ethereal.

## Test plan

Model (settings validation, recipients, digest), service (payload, PDF text,
QR decode manually), job (sent/cancelled/disabled/failed/no double send),
integration (authorization, list, preview, create, idempotency, digest
mismatch, retry, settings).

## Browser verification

Desktop and mobile: list button, billing page, preview, settings, send, run page;
emails in Ethereal.

## Risks

Duplicate emails on crash mid-SMTP (mitigated: `sending` not auto-retried);
font licensing (OFL fonts vendored with licences); QR scanner compatibility
(payload identical in structure to example, decoded in verification).

## Assumptions

See spec «NON-BLOCKING».

## Expected changed files

Gemfile(.lock), vendor/fonts/*, db/migrate/* ×3, db/schema.rb, app/models/{invoice_setting,invoice_run,participation_invoice}.rb,
app/services/{swiss_qr_bill,participation_invoice_pdf}.rb, app/mailers/participation_invoice_mailer.rb + views,
app/jobs/participation_invoice_delivery_job.rb, app/controllers/admin/{invoice_runs,invoice_settings}_controller.rb + views,
admin participations index, admin layout, routes, config/environments/development.rb, docs, tests.

## Definition of done

AGENTS.md checklist; `bin/rails test`, `bin/rubocop`, `bin/brakeman --no-pager`, browser flow.

## Final assessment

READY FOR IMPLEMENTATION
