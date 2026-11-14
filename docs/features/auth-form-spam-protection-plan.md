# Implementation Plan: Spam protection for public authentication forms

Specification: [`auth-form-spam-protection.md`](auth-form-spam-protection.md)

## Summary

This plan adds a reusable controller concern, `AuthSpamProtection`, plus a shared form partial. Together they add three checks to the four public, mail-sending Devise `create` actions (registration, password reset, confirmation resend, unlock resend):

- a honeypot field,
- a signed render timestamp that enforces a minimum fill time and a maximum form age,
- Rails 8 `rate_limit` per IP.

Registration also gets Cloudflare Turnstile through a small `TurnstileVerifier` service and a Stimulus controller. Turnstile is active only when both ENV keys are set. The plan adds no gems and no migrations.

## Existing system findings

- `Users::RegistrationsController`, `Users::PasswordsController`, and `Users::ConfirmationsController` already exist and are routed. `Users::UnlocksController` exists but is **not routed**, so `devise_for` falls back to `Devise::UnlocksController` (`config/routes.rb:12-17`).
- Rails 8.0.2.1 `ActionController::RateLimiting#rate_limit(to:, within:, by:, with:, store: cache_store, name:, **options)` adds a `before_action`. Its cache key is `rate-limit:<controller_path>:<name>:<ip>`. `store` is evaluated when the class is defined. In test, `cache_store` is a `NullStore`, so `increment` returns `nil` and the limit never triggers. Tests therefore need a swappable store.
- Production uses `solid_cache_store`, which supports `increment` with `expires_in`. Solid Cache stores the key (which contains the IP) in plain text until the entry expires. This corrects the spec's word "hashed"; the spec is updated to match.
- The auth views are German strings hard-coded in ERB, not i18n (`app/views/devise/**`). Messages follow that pattern.
- `devise/shared/_error_messages.html.erb` renders `resource.errors.full_messages` (base errors included) in a `role="alert"` box. The password, confirmation, and unlock views use it. The registration view renders `errors.full_messages_for(:base)` as `role="alert"` paragraphs.
- `auth_form_controller.js` touches only `[data-auth-password]`, so it won't interfere with the honeypot, timestamp, or Turnstile inputs.
- There's no CSP (`config/initializers/content_security_policy.rb` is commented out), so the Turnstile script and iframe load without policy changes.
- There's no WebMock or Mocha. Minitest 5.25's `Object#stub` (`minitest/mock`) is available to stub `Net::HTTP.start`.
- Existing tests POST to these endpoints without spam fields: `test/controllers/registration_notification_test.rb` and `test/controllers/email_previews_controller_test.rb`. Several of them assert `assert_no_emails` / `assert_no_enqueued_emails`. Once the timing check exists, those assertions would pass for the wrong reason, so the tests must send valid spam fields to keep testing what they intend (see Step 6).
- JavaScript tests evaluate controller source in a `vm` context with a stubbed `Controller` (`test/javascript/auth_form_controller_test.mjs`). The Turnstile controller can be tested the same way.
- README `## Deployment → ### Optional` holds the ENV variable table. `docs/security.md` covers security rules.

## Proposed design

### `AuthSpamProtection` concern (`app/controllers/concerns/auth_spam_protection.rb`)

Constants:

- `HONEYPOT_PARAM = :form_note`, a top-level param that is not nested under `user[...]` and doesn't resemble an autofill category.
- `TIMESTAMP_PARAM = :form_rendered_at`.
- `TOKEN_PURPOSE = :auth_form_rendered_at`.
- `MIN_FILL_TIME = 3.seconds`, `MAX_FORM_AGE = 24.hours`.
- `RETRY_MESSAGE = "Bitte prüfen Sie Ihre Angaben und senden Sie das Formular erneut."`
- `TURNSTILE_MESSAGE = "Bitte bestätigen Sie die Sicherheitsprüfung und senden Sie das Formular erneut."`
- `RATE_LIMIT_MESSAGE = "Zu viele Anfragen. Bitte versuchen Sie es in einigen Minuten erneut."`

Module functions:

- `self.form_token(now = Time.current)` returns `Rails.application.message_verifier(:auth_spam_protection).generate(now.to_f, purpose: TOKEN_PURPOSE, expires_in: MAX_FORM_AGE)`.
- `self.rendered_at(token)` returns a `Time` or `nil`. It uses `verified(token, purpose:)` and rescues bad input to `nil`. An expired, tampered, or wrong-purpose token gives `nil`.
- `RateLimitStore`: a tiny module-level object, `AuthSpamProtection.rate_limit_store`, that responds to `increment(key, amount, **opts)` by delegating to a swappable `backend` (default `Rails.cache`, resolved lazily). This keeps production on Solid Cache and lets tests swap in a `MemoryStore` and reset it.

Class macro `protect_auth_form(rate_limit:, turnstile: false)`:

- Calls `rate_limit to:, within:, only: :create, by: -> { request.remote_ip }, store: AuthSpamProtection.rate_limit_store, with: -> { reject_rate_limited }`.
- Adds `before_action :verify_auth_form_submission, only: :create`. This runs after `rate_limit` and after existing `before_action`s such as `configure_sign_up_params`, but before the Devise action body.

Instance methods:

- `verify_auth_form_submission` checks in order:
  1. Honeypot present → `log_spam_rejection(:honeypot)` and `respond_to_spam_as_success`.
  2. `rendered_at` is nil or `Time.current - rendered_at < MIN_FILL_TIME` → log `:timing` and `render_auth_form_retry(RETRY_MESSAGE)`.
  3. Turnstile enabled for this controller and `TurnstileVerifier.verify(...)` returns `:failure` → log `:turnstile` and `render_auth_form_retry(TURNSTILE_MESSAGE)`. If it returns `:unavailable` → log a warning and continue (fail open).
- `reject_rate_limited` logs `:rate_limit` and renders `devise/shared/rate_limited` with `layout: "auth"` and `status: :too_many_requests`.
- `log_spam_rejection(reason)` logs `Rails.logger.info "[auth_spam_protection] rejected endpoint=#{controller_path}##{action_name} reason=#{reason} request_id=#{request.request_id}"`. It never includes params.
- Hook methods each controller implements:
  - `respond_to_spam_as_success` redirects exactly as a successful submission does.
  - `build_auth_form_resource` builds the resource from permitted, non-secret params for re-rendering.

  The concern's `render_auth_form_retry(message)` calls `build_auth_form_resource`, adds `errors.add(:base, message)`, calls `clean_up_passwords(resource)`, and renders `:new` with `status: :unprocessable_entity`.

### Controller wiring

| Controller | Rate limit | Turnstile | Fake-success response | Retry resource |
|---|---|---|---|---|
| `Users::RegistrationsController` | 10 / 1.hour | yes | `redirect_to after_inactive_sign_up_path_for(nil)` (confirmation pending) | `build_resource(sign_up_params)` |
| `Users::PasswordsController` | 5 / 15.minutes | no | `set_flash_message!(:notice, :send_instructions)`; `redirect_to after_sending_reset_password_instructions_path_for(resource_name)` | `resource_class.new(email: resource_params[:email])` |
| `Users::ConfirmationsController` | 5 / 15.minutes | no | `set_flash_message!(:notice, :send_instructions)`; `redirect_to after_resending_confirmation_instructions_path_for(resource_name)` | same as passwords |
| `Users::UnlocksController` (newly routed) | 5 / 15.minutes | no | `set_flash_message!(:notice, :send_instructions)`; `redirect_to after_sending_unlock_instructions_path_for(resource)` | same as passwords |

`build_resource` in registrations already sets `registration_form`, `address`, and the business. That keeps the re-render identical to today's validation re-render.

### `TurnstileVerifier` service (`app/services/turnstile_verifier.rb`)

- `ENDPOINT = URI("https://challenges.cloudflare.com/turnstile/v0/siteverify")`.
- `self.enabled?` is true when both `ENV["TURNSTILE_SITE_KEY"]` and `ENV["TURNSTILE_SECRET_KEY"]` are present. `self.site_key` returns the site key.
- `self.verify(token:, remote_ip:)` returns `:failure` immediately for a blank token, without an HTTP call. Otherwise it calls `Net::HTTP.start(host, 443, use_ssl: true, open_timeout: 2, read_timeout: 3)` and POSTs the form body `secret`, `response`, `remoteip`.
  - 2xx with JSON `success: true` → `:success`.
  - JSON `success: false`, where `error-codes` doesn't include `internal-error` → `:failure`.
  - Non-2xx, `internal-error`, `JSON::ParserError`, `Net::OpenTimeout`, `Net::ReadTimeout`, `SocketError`, `SystemCallError`, or `OpenSSL::SSL::SSLError` → `:unavailable`.
- It never logs the secret or token. The controller logs `:unavailable` with only the reason class name.

### `config/initializers/turnstile.rb`

In `after_initialize`, it logs `Rails.logger.warn "[turnstile] disabled: TURNSTILE_SITE_KEY/TURNSTILE_SECRET_KEY not set"` when `Rails.env.production? && !TurnstileVerifier.enabled?`.

### Views

- `app/views/devise/shared/_spam_protection_fields.html.erb`:

  ```erb
  <div aria-hidden="true" class="absolute -left-[10000px] top-auto h-px w-px overflow-hidden">
    <label for="form_note">Bitte leer lassen</label>
    <input type="text" name="form_note" id="form_note" value="" tabindex="-1" autocomplete="off">
  </div>
  <%= hidden_field_tag :form_rendered_at, AuthSpamProtection.form_token, id: nil %>
  ```

  Each of the four `new` views renders it inside its form. The form container needs `relative` positioning only if clipping is an issue; with `-left-[10000px]` it is not.
- `app/views/devise/shared/_turnstile.html.erb` renders only `if TurnstileVerifier.enabled?`. It outputs `<div data-controller="turnstile" data-turnstile-site-key-value="…" class="flex justify-center"></div>`. The registration view renders it above the submit button.
- `app/views/devise/shared/rate_limited.html.erb` is a card in the existing auth style with a `role="alert"` message and a link back (`new_session_path(:user)`).
- Because each render of a `new` view calls `form_token`, a 422 re-render for an ordinary validation error gets a fresh timestamp automatically.

### Stimulus `turnstile_controller.js`

- `static values = { siteKey: String }`.
- `connect()` calls `loadScript()`, a single shared promise that injects `<script src="https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit" async defer>` once per page lifetime. When it resolves, it calls `window.turnstile.render(this.element, { sitekey, language: "de", size: this.element.clientWidth < 300 ? "compact" : "flexible" })` and stores the widget ID.
- `disconnect()` calls `window.turnstile?.remove(widgetId)` when the widget exists.
- On a Turbo visit or a 422 re-render, the element is replaced, so `disconnect` and `connect` give a new widget and a fresh token.
- It is registered in `app/javascript/controllers/index.js`, following that file's existing pattern (check whether it eager-loads or registers manually).

### Failure handling

All rejections happen in `before_action`s, so Devise's `create` never runs and nothing is persisted, tokenized, previewed, or mailed. The fail-open branch for Turnstile proceeds to normal Devise behavior.

## Data changes

None. There are no migrations. Rate-limit counters are transient Solid Cache entries that expire with their window.

## Authorization

No change. All four actions remain anonymous Devise endpoints, and existing `prepend_before_action :require_no_authentication` and similar guards stay in place. Rejections never sign anyone in or reveal account existence: the honeypot path returns the generic success redirect, and timing, Turnstile, and rate-limit rejections are identical whether or not the email exists. Admin login and member login are untouched. Routing `Users::UnlocksController` keeps the same paths and helpers (`user_unlock_path`).

## Implementation steps

### Step 1 — Concern, token, and rate-limit store

Files likely affected:
- `app/controllers/concerns/auth_spam_protection.rb` (new)

Changes:
- Constants, `form_token`/`rendered_at`, `rate_limit_store`, the `protect_auth_form` macro, the check and reject methods, logging, and abstract hooks that raise `NotImplementedError` by default.

Why:
- A single seam keeps the four controllers consistent and testable.

Verification:
- `test/controllers/concerns/auth_spam_protection_test.rb`: token round-trip; a token signed with a wrong purpose, a tampered token, and a token older than 24h (`travel`) all return nil.

Dependencies:
- None.

### Step 2 — Turnstile verifier and initializer

Files likely affected:
- `app/services/turnstile_verifier.rb` (new)
- `config/initializers/turnstile.rb` (new)

Changes:
- As designed above.

Why:
- Keeps the external integration out of controllers, as the services convention requires.

Verification:
- `test/services/turnstile_verifier_test.rb` stubs `Net::HTTP.start` and covers: enabled/disabled based on ENV; blank token → `:failure` with no HTTP call; success; `success: false` → `:failure`; `internal-error` → `:unavailable`; 500 → `:unavailable`; timeout → `:unavailable`; bad JSON → `:unavailable`; the POST body contains the secret, response, and remote IP.

Dependencies:
- None.

### Step 3 — Wire controllers and route unlocks

Files likely affected:
- `app/controllers/users/registrations_controller.rb`
- `app/controllers/users/passwords_controller.rb`
- `app/controllers/users/confirmations_controller.rb`
- `app/controllers/users/unlocks_controller.rb`
- `config/routes.rb` (adds `unlocks: "users/unlocks"`)

Changes:
- `include AuthSpamProtection`, the `protect_auth_form` call, and the two hook methods per the table above.

Why:
- REQ-001, REQ-004, REQ-006, REQ-008, and REQ-016.

Verification:
- `bin/rails routes -g unlock` shows the same paths, now mapped to `users/unlocks`.

Dependencies:
- Step 1, and Step 2 for registrations.

### Step 4 — Views and partials

Files likely affected:
- `app/views/devise/shared/_spam_protection_fields.html.erb` (new)
- `app/views/devise/shared/_turnstile.html.erb` (new)
- `app/views/devise/shared/rate_limited.html.erb` (new)
- `app/views/devise/registrations/new.html.erb`, `passwords/new.html.erb`, `confirmations/new.html.erb`, `unlocks/new.html.erb`

Changes:
- Render the spam fields in each form and the Turnstile partial in registration only.

Why:
- REQ-003, REQ-005, REQ-009, and REQ-011.

Verification:
- Integration GETs assert the honeypot attributes, the token presence, the Turnstile container only when ENV is set, and that the secret is absent from the HTML.

Dependencies:
- Steps 1 and 2.

### Step 5 — Stimulus Turnstile controller

Files likely affected:
- `app/javascript/controllers/turnstile_controller.js` (new)
- `app/javascript/controllers/index.js`, only if controllers are registered manually
- `test/javascript/turnstile_controller_test.mjs` (new)

Changes:
- As designed above.

Why:
- REQ-011 under Turbo.

Verification:
- The Node test (stubbed `document`/`window.turnstile`) covers: the script is injected once across two connects; `render` is called with the sitekey and `size` compact below 300px; `disconnect` calls `remove`.

Dependencies:
- Step 4.

### Step 6 — Tests

Files likely affected:
- `test/test_helper.rb`
- `test/controllers/auth_spam_protection_flow_test.rb` (new)
- `test/controllers/registration_notification_test.rb`
- `test/controllers/email_previews_controller_test.rb`

Changes:
- `test_helper.rb`: an `IntegrationTest` helper `auth_form_params(params, rendered_at: 10.seconds.ago)` that merges `form_rendered_at: AuthSpamProtection.form_token(rendered_at)` and `form_note: ""`.
- Update every existing POST to the four endpoints to use it. Assertions stay unchanged; only the inputs are made valid so they keep testing real behavior.
- The new flow test covers AC-001–AC-006, AC-008, AC-009, and AC-011:
  - honeypot per endpoint: no `User`/`Business` difference, no enqueued or delivered mail, the reset token is unchanged, and the redirect matches success;
  - timing too fast, missing, tampered, or expired per endpoint: 422, base message rendered, email value kept, nothing created;
  - rate limit: swap `AuthSpamProtection.rate_limit_store.backend` to `ActiveSupport::Cache::MemoryStore.new` in setup and restore it in teardown. Send N+1 requests with `REMOTE_ADDR`, check that request N+1 gets 429 and the message, and that another IP still succeeds;
  - Turnstile: set ENV keys in setup and restore them in teardown. Stub `TurnstileVerifier.verify` to return `:failure`/`:unavailable`/`:success`;
  - logs: capture `Rails.logger` output and assert the reason is present and the email/token/honeypot values are absent.
- Regression: `test/controllers/sessions_test.rb` (login unchanged), the token-based password update, and confirmation `show` still work.

Why:
- The requirement-to-verification matrix in the spec.

Verification:
- `bin/rails test` passes.

Dependencies:
- Steps 1–5.

### Step 7 — Documentation

Files likely affected:
- `README.md` (`### Optional` table)
- `docs/security.md` (a short "Public form spam protection" section)
- `docs/features/auth-form-spam-protection.md` (fix the cache-key wording)

Changes:
- Document `TURNSTILE_SITE_KEY` and `TURNSTILE_SECRET_KEY`, the fail-open behavior, the rollout order (verify `remote_ip` first, privacy policy before keys), and the invariant that public mail-sending forms must use `protect_auth_form`.

Why:
- Lasting invariant plus new environment variables (AGENTS.md).

Verification:
- Read-through.

Dependencies:
- None.

## Test plan

| AC | Coverage |
|---|---|
| AC-001 | Existing `RegistrationNotificationTest` (now with valid spam params); new flow test with Turnstile `:success` |
| AC-002 | Flow test: honeypot × 4 endpoints |
| AC-003, AC-004 | Flow test: timing/missing/tampered/wrong purpose/expired × 4 endpoints; concern unit test |
| AC-005, AC-006 | Flow test with `MemoryStore` backend and IP isolation |
| AC-007 | View test for the container; Node controller test; browser check (direct load, Turbo visit, 422 re-render) |
| AC-008, AC-009 | Flow test with stubbed verifier; verifier unit tests |
| AC-010 | View test without ENV keys: no `data-controller="turnstile"` and no Cloudflare URL |
| AC-011 | Log capture assertion |
| AC-012 | Existing `sessions_test.rb`, `email_previews_controller_test.rb`, full suite |
| AC-013 | View attribute assertions; manual keyboard tab-through in the browser |

Concurrency: rate-limit `increment` is atomic in Solid Cache and MemoryStore. No other shared mutable state is involved.

## Browser verification

Run `bin/dev` and check:

1. Registration at desktop width and at 375px/320px: the honeypot is invisible, Tab skips it, and real registration succeeds after a few seconds.
2. Submitting registration within about a second shows the retry alert, keeps the values, and a second submit succeeds.
3. With the Cloudflare **test keys** (site `1x00000000000000000000AA` / secret `1x0000000000000000000000000000000AA` always pass; `2x…AA` always fails) set in `.env`: the widget renders on a direct load, on a Turbo visit from the login page, and after a 422 (for example a taken email). It fits at 320px.
4. Password reset, confirmation resend, and unlock forms: normal submission works and a fast submission shows the retry alert.
5. Rate limit: repeated reset requests show the 429 page.

## Risks

| Risk | Likelihood/impact | Mitigation | Remaining exposure |
|---|---|---|---|
| `remote_ip` is the proxy IP in production, so all users share one bucket | Low–medium / high (everyone locked out of sign-up for an hour) | Rollout check of logs before relying on it; generous limits; Rails trusts private ranges by default | Must be verified after deploy |
| False positives from password-manager fast submit on the short forms | Medium / low | Visible retry message, not silent | Minor friction |
| Turnstile blocked by ad blockers | Low / medium for affected users | Clear message; only on registration | Accepted trade-off |
| Turnstile enabled without a privacy-policy update | Medium / legal | Gated on ENV keys; documented rollout | Client action required |
| Targeted bots bypass the honeypot and timing checks | Medium / low | Rate limit + Turnstile | Acceptable |
| Existing tests silently become vacuous | Was certain before mitigation | Step 6 updates inputs, not assertions | None |

## Assumptions

- **CONFIRMED**: cover registration, password reset, confirmation resend, and unlock resend; honeypot + timing + rate limit on all four; Turnstile on registration (developer, 2026-11-14).
- **INFERRED**: Dokploy/Traefik forwards `X-Forwarded-For` from a private-range IP, so Rails' default trusted proxies give the client IP. Based on Docker networking and the absence of Cloudflare headers.
- **ASSUMED**: thresholds (10/h, 5/15min), minimum fill time of 3s, maximum form age of 24h, Turnstile fail-open on outage, and German-only messages (auth views are hard-coded German).

## Expected changed files

- New:
  - `app/controllers/concerns/auth_spam_protection.rb`
  - `app/services/turnstile_verifier.rb`
  - `config/initializers/turnstile.rb`
  - `app/views/devise/shared/_spam_protection_fields.html.erb`
  - `app/views/devise/shared/_turnstile.html.erb`
  - `app/views/devise/shared/rate_limited.html.erb`
  - `app/javascript/controllers/turnstile_controller.js`
  - `test/controllers/auth_spam_protection_flow_test.rb`
  - `test/controllers/concerns/auth_spam_protection_test.rb`
  - `test/services/turnstile_verifier_test.rb`
  - `test/javascript/turnstile_controller_test.mjs`
- Modified:
  - `app/controllers/users/{registrations,passwords,confirmations,unlocks}_controller.rb`
  - `config/routes.rb`
  - `app/views/devise/{registrations,passwords,confirmations,unlocks}/new.html.erb`
  - `test/test_helper.rb`
  - `test/controllers/registration_notification_test.rb`
  - `test/controllers/email_previews_controller_test.rb`
  - `README.md`
  - `docs/security.md`
  - `docs/features/auth-form-spam-protection.md`
- Uncertain: `app/javascript/controllers/index.js`, only if controllers are registered manually.

## Definition of done

- AC-001–AC-013 are each backed by the evidence listed in the test plan.
- These commands pass:
  - `bin/rails test`
  - `node --test test/javascript/*_test.mjs`
  - `bin/rubocop`
  - `bin/brakeman --no-pager`
- The browser flows above are verified, including 320px and keyboard.
- The full diff is reviewed: no unrelated changes, and no logging of emails, tokens, or secrets.
- README and `docs/security.md` are updated.
- After deploy (operational): confirm `remote_ip` in production logs, then the client updates the privacy policy, then Turnstile keys are set in Dokploy.

## Independent plan review (2026-11-14)

Verdict: **APPROVED WITH CHANGES**. The reviewer checked the plan against the Devise 4.9.4, actionpack 8.0.2.1 and solid_cache 1.0.7 source.

**Confirmed:**
- CSRF and `ApplicationController` callbacks run before the `rate_limit` and verify callbacks.
- The `rate_limit` signature and the store proxy work. `name:` isn't needed. `remote_ip` keying is spoof-resistant.
- The message-verifier round-trip works.
- Routing unlocks keeps the same paths, helpers and view lookup.
- `index.js` eager-loads controllers, so it needs no change.
- No other tests become vacuous.

These changes are adopted and override the design above where they conflict:

1. **Unlock fake success.** Use `after_sending_unlock_instructions_path_for(resource_name)`, not `(resource)`. `resource` is nil in a before_action and would raise.
2. **Fake-success status.** All four fake-success redirects use `status: :see_other`, matching Devise's `responder.redirect_status`.
3. **Parameter filtering.** Add `:form_note` and `/turnstile/` to `config/initializers/filter_parameter_logging.rb`, so the token and honeypot never reach the request log.
4. **Unlock page layout.** Add `layout "auth"` to `Users::UnlocksController`. The honeypot wrapper also gets an inline `style="position:absolute;left:-10000px;width:1px;height:1px;overflow:hidden"`, so it stays hidden without Tailwind.
5. **Password hint on retry.** `render_auth_form_retry` calls `set_minimum_password_length` when the controller responds to it, so the registration hint still shows.
6. **Registration fields on retry.** `build_auth_form_resource` in registrations calls `configure_sign_up_params` itself, so it doesn't depend on callback declaration order.
7. **Turnstile under Turbo.**
   - The registration page sets `<meta name="turbo-cache-control" content="no-cache">` through `content_for :head`.
   - The Stimulus controller clears its container in `connect`.
   - It skips rendering if `!this.element.isConnected` once the script resolves.
8. **Network errors and timeouts.**
   - The verifier rescues `Net::OpenTimeout`, `Net::ReadTimeout`, `Net::WriteTimeout`, `Timeout::Error`, `EOFError`, `IOError`, `SocketError`, `SystemCallError`, `OpenSSL::SSL::SSLError`, `Net::HTTPBadResponse`, `Net::ProtocolError` and `JSON::ParserError`, all mapped to `:unavailable`.
   - The timeouts are open 2s, ssl 2s and read 3s.
9. **Misconfigured secret.** The `invalid-input-secret`, `missing-input-secret` and `internal-error` codes map to `:unavailable` and are logged at error level, so a wrong secret can't block every registration.
10. **Form age.** `rendered_at` also rejects `Time.current - rendered_at > MAX_FORM_AGE` (not just the verifier's `expires_in`), and the token is generated with `expires_at: now + MAX_FORM_AGE`.
11. **Non-string tokens.** `rendered_at` returns nil unless the token is a `String`.
12. **Resource assignment.** The password, confirmation and unlock `build_auth_form_resource` hooks assign `self.resource = resource_class.new(email: …)`.
13. **Retry messages.**
    - Registration shows the spam message as a base error without the "Bitte prüfen Sie die markierten Felder." hint. The view suppresses that hint when only base errors exist.
    - The other three views keep the shared error partial.
14. **Not adopted / documentation only.**
    - Email-preview mode: a honeypot fake success shows no preview link. This is acceptable, because a human never trips the honeypot.
    - The "Turnstile disabled" warning is logged once per process, not once overall.
    - Solid Cache's failsafe makes rate limiting fail open if the cache DB errors. This goes in `docs/security.md`.
    - Siteverify `hostname` checking stays out of scope.

## Final assessment

READY FOR IMPLEMENTATION
