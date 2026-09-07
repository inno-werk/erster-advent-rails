# Implementation Plan: Signup validation and address split

## Summary

Add signup-only virtual address fields and model validation, compose them into the existing persisted fields, update the Devise view/error mapping, harden the password visibility control, and cover the complete boundary with Rails, JavaScript, and browser tests.

## Existing system findings

- Devise's custom registrations controller builds an autosaved `Business` together with the `User`.
- The persisted `User#address` is legacy registration data; `Business#address` and `Business#billing_address` are the active display sources.
- Devise already validates email/password. `Business` presence errors are surfaced via `AuthFormsHelper`.
- Stimulus controllers are eager-loaded through Importmap, and one shared password visibility controller serves signup, login, and reset forms.
- Existing test signup phone values contain spaces, which conflict with the newly requested strict format and must be adjusted where those tests exercise successful signup.

## Proposed design

`User` will expose transient signup street and postal/locality attributes plus a transient registration-validation flag. The controller will mark resources built by the public registration flow, compose the full legacy address, and build the associated business. The business builder will put only the street line into `address` and the composed two-line value into `billing_address`. Signup-only model validation will enforce contact-name/address presence and the phone grammar without tightening unrelated admin/personal-edit flows.

The view will render the two virtual address inputs, pass browser constraints for email and phone, and map validation errors to their exact visible fields. The password controller/button will use an explicit click action, prevent default behavior, and synchronize `aria-pressed` and accessible label state.

## Data changes

None. No migration, backfill, index, or rollback data operation is required.

## Authorization

No change. Devise continues to own public account creation. Strong parameters gain only the two transient address inputs. Role, ownership, status, and payment fields remain excluded.

## Implementation steps

### Step 1 — Add signup boundary attributes and validation

Files likely affected:

- `app/models/user.rb`
- `app/controllers/users/registrations_controller.rb`

Changes:

- Add virtual street/postal inputs and a registration-context marker.
- Validate required signup values and strict phone format in that context.
- Compose the legacy full address and synchronize the registration business destinations.
- Permit the virtual inputs.

Why:

- This keeps the rule server-enforced and avoids changing storage or unrelated editors.

Verification:

- Focused Rails registration integration tests.

Dependencies:

- None.

### Step 2 — Update field rendering and password interaction

Files likely affected:

- `app/views/devise/registrations/new.html.erb`
- `app/helpers/auth_forms_helper.rb`
- `app/javascript/controllers/password_visibility_controller.js`

Changes:

- Replace the single address field with the two requested inputs and exact labels.
- Add suitable autocomplete, input mode, and pattern attributes.
- Map errors to the virtual inputs.
- Make password activation/state semantics explicit.

Why:

- Users need immediate native hints plus accessible server feedback and a dependable visibility control.

Verification:

- Render assertions, JavaScript tests, and live browser interaction.

Dependencies:

- Step 1.

### Step 3 — Add regression coverage and update durable documentation

Files likely affected:

- `test/controllers/registration_notification_test.rb`
- `test/javascript/auth_form_controller_test.mjs`
- `docs/participation-and-print-materials.md`

Changes:

- Cover valid persistence, invalid email/phone/address values, input metadata, password accessibility state, and no orphan/email side effects.
- Update existing successful signup payloads to meet the new format.
- Document the lasting address/validation invariant.

Why:

- The behavior crosses UI, validation, persistence, and the existing notification flow.

Verification:

- Focused test files followed by the repository's full required checks.

Dependencies:

- Steps 1–2.

## Test plan

- Rails integration: valid two-line composition; invalid email; invalid phone variants; each address field blank; accessible errors; password absent from HTML; no records or queued mail on failure.
- JavaScript: visibility state initializes masked, toggles twice, preserves value, prevents default, and updates label/pressed state.
- Regression: all Rails tests, all JavaScript tests, RuboCop, Brakeman, and relevant system tests if present.

## Browser verification

Run the local app and exercise `/users/sign_up` at desktop and narrow mobile widths. Confirm the split field layout, native invalid email/phone blocking, server error rendering, and password toggle through mouse and keyboard activation. Complete one valid signup using a unique test email and confirm the resulting business summary destinations when practical.

## Risks

- Autosave timing could build the business before address composition. Mitigation: compose and synchronize explicitly during controller resource construction, then prove persisted values.
- A global phone validation could reject legacy/spaced values in other flows. Mitigation: scope the new format to public registration.
- Turbo could replace the form while a visible password is active. Mitigation: retain the existing scrub/restore behavior and ensure the visibility controller always reconnects masked.

## Assumptions

- **CONFIRMED** — No schema split is required to achieve the requested display destinations.
- **INFERRED** — An optional leading `+` is the intended phone grammar.
- **ASSUMED** — Postal/locality remains free-form and required.

## Expected changed files

- `app/models/user.rb`
- `app/controllers/users/registrations_controller.rb`
- `app/helpers/auth_forms_helper.rb`
- `app/views/devise/registrations/new.html.erb`
- `app/javascript/controllers/password_visibility_controller.js`
- `test/controllers/registration_notification_test.rb`
- `test/javascript/auth_form_controller_test.mjs`
- `docs/participation-and-print-materials.md`
- This specification and plan.

## Definition of done

- All acceptance criteria pass with code/test evidence.
- Focused and full Rails/JavaScript tests pass.
- RuboCop and Brakeman pass.
- Browser verification covers interaction, validation, and responsive rendering.
- Full diff is reviewed for scope, security, password handling, and existing-data compatibility.

## Final assessment

READY FOR IMPLEMENTATION
