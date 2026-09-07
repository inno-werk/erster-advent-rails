# Feature: Signup validation and address split

## Goal

Make `/users/sign_up` reject malformed contact data, provide a working password visibility control, and collect the street and postal locality separately while preserving the existing business and billing-address model.

## Actors

- Anonymous prospective members submit the signup form.
- The new member and administrators later read the resulting business and billing details.

## Current behavior

- Signup renders one required address input and copies its value to both `Business#address` and `Business#billing_address`.
- Devise validates the email and password on the server. Nested `Business` validation supplies presence errors for business name, phone, address, and billing address.
- The contact name is only browser-required. Phone has no format validation.
- A Stimulus password-visibility controller exists, but the signup control is reported not to work.
- The business summary renders `Business#address` under “Geschäftsinformationen” and the full `Business#billing_address` under “Kontaktinfos”.

## Desired behavior

The signup form has distinct “Strasse + Hausnummer” and “PLZ + ORT” inputs. Successful registration stores the street-only value as the business address and the two values, separated by a line break, as the billing address and legacy registration address. Email, phone, required text inputs, and password are validated with accessible field errors. The password control reliably switches between masked and visible text without changing its value.

## Functional requirements

- REQ-001 — The signup email must satisfy Devise's email format validation and use the browser email input type.
- REQ-002 — The signup phone must contain digits only, with one optional leading `+`; blank, letters, punctuation, spaces, and a non-leading `+` are invalid.
- REQ-003 — Business name, contact name, street/house number, postal code/locality, phone, email, and password remain required and receive field-level errors when invalid.
- REQ-004 — Signup must collect street/house number separately from postal code/locality.
- REQ-005 — Successful signup must copy street/house number to `Business#address`, compose street plus postal locality into `Business#billing_address`, and retain that composed value in the legacy `User#address` field.
- REQ-006 — The password visibility button must toggle its input between `password` and `text`, preserve the value, expose its state accessibly, and never submit the form itself.
- REQ-007 — Invalid registration must create neither a user nor a business, must preserve non-password field values, and must not expose the password in response HTML.

## Acceptance criteria

- AC-001 — Given a malformed email, when signup is submitted, then the email field has an accessible inline error and no records are created.
- AC-002 — Given a phone containing anything other than digits or one leading `+`, when signup is submitted, then the phone field has an accessible inline error and no records are created.
- AC-003 — Given either address input is blank, when signup is submitted, then that exact field has an accessible inline error and no records are created.
- AC-004 — Given valid signup data, when registration succeeds, then the business address equals the street input and the billing/user address equals `street + "\n" + postal locality`.
- AC-005 — Given a password value, when the visibility button is activated twice, then the type changes password → text → password and the value is unchanged.
- AC-006 — Given a validation failure, when the page is rendered, then all affected visible fields are marked and the password is absent from response HTML.

## Authorization

The route remains public through Devise. No App or Admin authorization behavior changes. Submitted role, owner, business status, and paid state remain untrusted and unpermitted.

## Data and persistence

No schema change. `User#address` remains the legacy full postal address. `Business#address` holds the street line, and `Business#billing_address` holds both entered lines. Existing rows are unchanged.

## External side effects

Existing confirmation and optional registration-notification behavior is unchanged. Invalid submissions enqueue and send no email.

## Security and privacy

Validation is server-side as well as expressed through HTML constraints. Password retention remains browser-memory-only during Turbo validation and is scrubbed before snapshots/navigation. No submitted password is rendered, logged, or persisted outside Devise's encrypted password.

## UI states

- Initial: required inputs use suitable autocomplete/input metadata.
- Validation: each invalid input gets an error border, `aria-invalid`, `aria-describedby`, and an inline alert.
- Password visibility: button state and accessible label change with masking state.
- Success: existing confirmation/setup navigation remains unchanged.

## Edge cases

- `+` is allowed only as the first phone character and only once.
- International postal/locality text is free-form but nonblank; no Swiss-only PLZ assumption is imposed.
- Existing multiline addresses continue to initialize legacy businesses without data loss.
- Whitespace-only values are invalid through Rails presence validation.

## Compatibility / migration

The change is additive at the form/model boundary. No migration or backfill is needed. Existing business editing remains free-form and retains its current validation behavior.

## Out of scope

- Splitting address columns in the database.
- Reworking the member/admin business editors.
- Normalizing or reformatting existing phone/address data.
- Geocoding or validating that a postal address exists.

## Evidence

- **CONFIRMED** — The requested field rules and destination displays come from the client request.
- **CONFIRMED** — `app/controllers/users/registrations_controller.rb` builds a business during Devise registration and permits the current signup fields.
- **CONFIRMED** — `app/models/user.rb` currently copies one address to both business address fields.
- **CONFIRMED** — `app/views/app/mystore/show.html.erb` renders business address and billing address in the requested sections.
- **CONFIRMED** — `app/helpers/auth_forms_helper.rb` maps nested validation errors onto visible signup fields.
- **INFERRED** — “Only numbers and +” means digits with an optional single leading plus, because that is the conventional unambiguous international-number form.
- **ASSUMED** — Postal code and locality remain one free-form required field, as requested, rather than being structurally validated to Swiss addresses.

## Open questions

### BLOCKING

None.

### NON-BLOCKING

- Whether existing phone values should be normalized. Conservative default: validate only this signup boundary and leave existing records/editors unchanged.
- Whether `PLZ + ORT` must be Swiss-only. Conservative default: require a nonblank value without rejecting valid foreign addresses.

## Requirement-to-verification matrix

| Requirement | Acceptance criteria | Verification approach |
|---|---|---|
| REQ-001 | AC-001, AC-006 | Rails integration test and browser native validation check |
| REQ-002 | AC-002, AC-006 | Rails integration/model-boundary tests and input attribute assertion |
| REQ-003 | AC-001, AC-003, AC-006 | Rails integration tests |
| REQ-004 | AC-003, AC-004 | View assertions and successful registration test |
| REQ-005 | AC-004 | Persistence assertions |
| REQ-006 | AC-005 | JavaScript test and browser interaction |
| REQ-007 | AC-001, AC-002, AC-003, AC-006 | Count, email-queue, and response-body assertions |

## Final assessment

READY FOR PLANNING
