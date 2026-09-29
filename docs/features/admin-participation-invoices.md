# Feature: Participation invoices with Swiss QR bill by email

## Goal

Administrators send every business with an open participation amount for the
active event year a German PDF invoice with a Swiss QR bill, attached to an
email. Bank details are maintained by the admin without a deploy. The invoice
layout reproduces `docs/QR_Rechnung_A_haarglanz.pdf`.

## Actors

- **Admin / Superadmin** (`adminish?`) — reviews recipients, edits subject and
  text, previews the PDF, sends, retries failures, maintains bank details.
- **Member (recipient)** — receives one email with one PDF invoice per mailing.
- **Excluded** — anonymous visitors and members must not reach any page,
  preview, or send action; deactivated users (`users.deleted`) are not billed.

## Current behavior

- `/admin/participations?payment_status=pending` lists participations of a
  year whose participation is unpaid, or paid «Kein Eintrag» with a pending
  listed upgrade. (CONFIRMED — `Admin::ParticipationsController#index`)
- `Participation#amount_due_cents` is the snapshotted open amount: the full
  price when unpaid, otherwise the payable upgrade difference. (CONFIRMED)
- No invoice, bank detail, or QR-bill functionality exists. `Admin::InvoicesController`
  is an unrelated «under construction» placeholder for legacy orders. (CONFIRMED)
- Mail is only delivered with `PROD_SEND=true`; development uses letter_opener
  and has no SMTP configuration. (CONFIRMED — `EmailDelivery`, `config/environments/*`)
- Development runs Active Job with the in-process async adapter; production uses
  Solid Queue. (CONFIRMED)

## Desired behavior

1. A «Rechnungen versenden» button at the top right of the Zahlungen list opens
   a billing page for the active event year (`EventConfiguration.year`).
2. The billing page lists every business with an open amount, shows email,
   category, open amount, total, missing-address problems and when a bill was
   last sent; the admin edits the email subject and a text used as the PDF
   introduction and the email opening, previews the PDF per business, and sends.
3. Bank details (account holder, structured address, IBAN, bank name) and the
   letterhead are editable on the billing page and on a new admin menu entry
   «Bankverbindung».
4. Sending creates an auditable run with one invoice record per business, then
   delivers each email in a background job with the PDF attached. The run page
   shows per-recipient status and allows retrying failed deliveries.

## Functional requirements

- REQ-001 — Admin-only billing page reachable from the Zahlungen list header.
- REQ-002 — Recipients are exactly the active-year participations of non-deleted
  users with `amount_due_cents > 0`. Amount = `amount_due_cents` (CHF 250.00 for
  an unpaid Nicht-Leistmitglied, CHF 200.00 Leistmitglied, CHF 100.00 Kein
  Eintrag, or the payable upgrade difference).
- REQ-003 — Subject (required, ≤ 150 chars) and text (required, ≤ 1200 chars)
  are editable; defaults follow the example invoice for the active year.
- REQ-004 — PDF page 1 reproduces the example: letterhead, recipient block,
  «Bern, <date>», title, subtitle «Rechnung Teilnahmebeitrag <year>», admin
  text, position table (Pos/Betreff/Menge/Preis/Total, «Teilnahmebeitrag
  <year> / Kat. A|B|C», «Betrag exkl. MwSt.*»), VAT footnote, bank line,
  closing text and greeting. Page 2 contains the QR-bill payment part.
- REQ-005 — The QR code follows Swiss Payment Standards IG QR-bill v2.x exactly
  as the example: `SPC/0200/1`, IBAN, structured (`S`) creditor address, no
  ultimate creditor, amount with 2 decimals, `CHF`, no debtor, reference type
  `NON`, unstructured message «Rechnung Erster Advent <year>, Kategorie <X>:
  CHF <amount> (<title>)», trailer `EPD`, CRLF, error correction M, 46 mm, Swiss
  cross.
- REQ-006 — Bank details are validated: Swiss/Liechtenstein IBAN with valid
  checksum, not a QR-IBAN; address fields within QR-bill limits and character
  set. Sending is refused until valid bank details are saved.
- REQ-007 — Each email goes to the account email, contains the admin text, a
  fixed summary with amount, and the PDF attachment.
- REQ-008 — Duplicate protection: a run is created at most once per form
  submission (unique idempotency key); a run is refused if the recipient list
  or amounts changed since the page was rendered; each invoice is delivered at
  most once by jobs (state claim under lock); re-sent only by explicit admin retry of failed ones.
- REQ-009 — Before delivery the job re-checks `PROD_SEND` and that the
  participation still owes the same amount; otherwise the invoice is cancelled
  or failed with a reason and no email is sent.
- REQ-010 — Sending is refused while `PROD_SEND` is not `true`, or while any
  recipient lacks a name/address.

## Acceptance criteria

- AC-001 — Given an admin on `/admin/participations`, then a «Rechnungen
  versenden» link to the billing page is shown top right.
- AC-002 — Given unpaid A/B/C participations, a paid one, a payable upgrade,
  a deleted user and a previous-year one, the billing page lists exactly the
  unpaid three plus the upgrade with 200/250/100/difference.
- AC-003 — Given a member or anonymous user, every billing, preview, send,
  retry, and settings endpoint redirects without effect.
- AC-004 — Given valid settings, the preview PDF has 2 A4 pages, the page-1
  text of the example with the recipient's data, and a QR payload byte-identical
  in structure to the example for the same data.
- AC-005 — Given a send, one run and N invoices are created, N emails with a
  PDF attachment are delivered to the account emails with the chosen subject.
- AC-006 — Given the same form is submitted twice, only one run exists and no
  additional email is sent.
- AC-007 — Given a participation paid after the run was created, its job sends
  no email and marks the invoice cancelled.
- AC-008 — Given `PROD_SEND` is not `true`, sending is refused and a job does not deliver.
- AC-009 — Given an invalid IBAN / QR-IBAN, settings are not saved and errors are shown.
- AC-010 — Given a failed delivery, the admin can retry; sent invoices are never re-sent by retry.

## Authorization

All endpoints live under `Admin::` and inherit `require_admin!`. Recipients are
derived server-side; no participation, user, amount, or email is accepted from
the browser except the preview's participation id, which is looked up only
within the computed recipient set.

## Data and persistence

- `invoice_settings` (single row): creditor name, street, building number,
  postal code, town, country, IBAN, bank name, letterhead.
- `invoice_runs`: year, subject, message, creditor snapshot (jsonb), creator,
  idempotency key (unique), timestamps.
- `participation_invoices`: run, participation, optional upgrade, user, year,
  category, amount_cents (> 0), description, recipient email/name/address
  snapshot, status (`queued/sending/sent/failed/cancelled`), sent_at, error,
  unique (run, participation). Rows are retained as audit; users are not
  hard-deleted through the product flow, `participation_id` uses `on_delete: :cascade`
  consistent with the participation dependency.
- Additive migrations only.

## External side effects

Emails via Action Mailer from a job; `before_deliver` re-checks `PROD_SEND`.
Jobs are not automatically retried (to avoid duplicate bills). A crash during
SMTP leaves the invoice in `sending`, shown as «unklar» and never retried
automatically.

## Security and privacy

No bank credentials are involved; IBAN of the association is not secret.
PDFs are generated on demand and not stored. Previews are `no-store`. Errors
stored on invoices contain only exception class and message (no bodies).
CSRF applies to every POST/PATCH.

## UI states

Empty list («Keine offenen Zahlungen»), missing settings, missing addresses,
preview mode (PROD_SEND off), validation errors, confirmation before sending,
run status with counts and per-row state, retry.

## Edge cases

Double submit; list changes between render and submit; payment during sending;
category change during sending; SMTP failure; very long text (validated
length; PDF refuses overflow); characters outside the QR charset in settings.

## Compatibility / migration

New tables only. Development may use Ethereal SMTP through `SMTP_ADDRESS` et al.
when set; otherwise letter_opener remains.

## Out of scope

Payment reconciliation/import, QR/SCOR references, selecting a subset of
recipients, invoices for print orders, storing PDFs, non-German invoices.

## Evidence

- Example PDF decoded payload (CONFIRMED):
  `SPC 0200 1 CH96…218 S «Erster Advent Untere Altstadt Bern» Wasserwerkgasse 29 3011 Bern CH … 200.00 CHF … NON «Rechnung Erster Advent 2026, Kategorie A: CHF 200.00 (Leistmitglied)» EPD`.
- Category letters: A = Leistmitglied (example), C = Kein Eintrag
  (`docs/participation-and-print-materials.md`), B = Nicht-Leistmitglied (INFERRED).
- Recipient address = `businesses.billing_address` with business name, fallback
  to the user's business name/address (INFERRED — signup prefills it).

## Open questions

### BLOCKING

None.

### NON-BLOCKING

- Include paid «Kein Eintrag» members with an open upgrade difference? Default:
  yes, billed for the difference — they appear in the linked «Zahlung offen» filter.
- «Zahlbar durch» on the QR bill? Default: empty as in the example.
- Closing text / 30-day term: fixed as in the example.
- Deactivated users: excluded.

## Requirement-to-verification matrix

| Requirement | Acceptance criteria | Verification approach |
|---|---|---|
| REQ-001 | AC-001 | Integration test, browser |
| REQ-002 | AC-002 | Model/integration test |
| REQ-003 | AC-005 | Integration test |
| REQ-004 | AC-004 | PDF text test, visual comparison with example |
| REQ-005 | AC-004 | Payload unit test vs. decoded example, QR decode of rendered PDF |
| REQ-006 | AC-009 | Model test |
| REQ-007 | AC-005 | Mailer/integration test |
| REQ-008 | AC-006, AC-010 | Integration/job tests |
| REQ-009 | AC-007, AC-008 | Job tests |
| REQ-010 | AC-008 | Integration test |
| Authorization | AC-003 | Integration test |

## Final assessment

READY FOR PLANNING
