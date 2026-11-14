# Feature: Spam protection for public authentication forms

## Goal

Stop automated spam submissions through the public authentication forms. Today every bot sign-up creates a junk account and business, sends an admin notification «Neue Registrierung: …» to `info@erster-advent-bern.ch`, and sends a Devise confirmation email to whatever address the bot entered. The password-reset, confirmation-resend, and unlock-resend forms can likewise be abused to send mail to arbitrary addresses. Real members must be able to register and recover their accounts without extra friction.

## Actors

- **Anonymous visitor (human)**: registers, requests a password reset, or resends confirmation/unlock instructions. Must not be blocked during normal use.
- **Automated bot**: submits the same forms in bulk. Must be rejected before any record is created or mail is queued.
- **Admin mailbox (`info@erster-advent-bern.ch`)**: receives registration notifications and should only receive them for submissions that pass the spam checks.
- **Operator/deployer**: configures the Cloudflare Turnstile keys and checks rate-limit behavior behind the production proxy.
- **Excluded**: authenticated members and admins editing their own data (App/Admin forms are not public and are out of scope).

## Current behavior

- The URL the client mentioned, `/users/sign_in`, is the Devise login page (`app/views/devise/sessions/_login.html.erb`). It has no contact form, only a link to «Registrieren». **CONFIRMED**
- The app has no contact form at all (no route, controller, or view). **CONFIRMED**
- `POST /users` (`Users::RegistrationsController#create`) creates a `User` and a pending `Business`. It queues `RegistrationMailer.new_registration` to `info@erster-advent-bern.ch` when `PROD_SEND` is enabled and sends a Devise confirmation email (`:confirmable`). **CONFIRMED**
- `POST /users/password`, `POST /users/confirmation`, and `POST /users/unlock` send Devise mail to any registered address that is submitted. **CONFIRMED** (Devise `:recoverable`, `:confirmable`, `:lockable`; routes from `devise_for :users`)
- None of these forms has a CAPTCHA, honeypot, timing check, or rate limit. The repository contains no `rack-attack`, `rate_limit`, `recaptcha`, `hcaptcha`, `turnstile`, or `invisible_captcha`. **CONFIRMED**
- No Content Security Policy is enforced (`config/initializers/content_security_policy.rb` is entirely commented out). **CONFIRMED**
- Production uses `solid_cache_store`, which Rails 8 `rate_limit` can use; test uses `null_store`. **CONFIRMED** (`config/environments/*.rb`)
- Production responses show no Cloudflare proxy headers. The app runs behind Dokploy (Traefik) in Docker. **INFERRED** from response headers on 2026-11-14 and `config/environments/production.rb`
- Most likely source of the reported «spam»: bot registrations, which generate admin notifications and junk accounts. The client could not confirm this. **ASSUMED**: the developer chose to protect all public mail-sending auth forms.

## Desired behavior

Every public form that creates an account or triggers an email runs inexpensive invisible checks before any record or email is created: a honeypot field, a minimum fill time, and a per-IP rate limit. The registration form additionally requires a Cloudflare Turnstile token, verified on the server, whenever Turnstile is configured. Humans see no extra steps in the normal case. Bots are rejected without creating users or businesses and without queueing mail.

## Functional requirements

### Scope of protected endpoints

- REQ-001: The protections apply to these public POST endpoints, in all locale-prefixed variants: registration (`user_registration_path`, create), password reset request (`user_password_path`, create), confirmation resend (`user_confirmation_path`, create), and unlock resend (`user_unlock_path`, create).
- REQ-002: Login (`user_session_path`, `admin_session_path`), password update via token (PUT `user_password_path`), confirmation via token (GET), and authenticated App/Admin forms keep their current behavior.

### Honeypot

- REQ-003: Each protected form contains a honeypot text input that humans cannot see, that is skipped by keyboard navigation (`tabindex="-1"`), hidden from assistive technology, and excluded from browser autofill (`autocomplete="off"`, with a name that does not resemble a real address/contact field).
- REQ-004: If the honeypot contains any value, the server performs none of the endpoint's side effects (no user, business, token, or email) and returns the same response a successful submission would give, so the bot gets no feedback.

### Minimum fill time

- REQ-005: Each protected form carries a tamper-proof, server-generated timestamp of when the form was rendered. It is signed with a dedicated purpose, so no other signed token is accepted in its place.
- REQ-006: If the timestamp is missing, tampered, or shows the form was submitted less than the minimum fill time (default 3 seconds) after rendering, the server performs none of the side effects. It re-renders the form with HTTP 422, keeps the entered non-secret values, and shows a generic German message asking the person to check the details and submit again. The re-rendered form carries a fresh timestamp.
- REQ-007: A form older than the maximum age (default 24 hours) is treated like a missing timestamp (REQ-006), so captured tokens cannot be replayed indefinitely.

### Rate limiting

- REQ-008: Each protected endpoint is rate-limited per client IP. Defaults: registration 10 per hour; password reset, confirmation resend, and unlock resend 5 per 15 minutes each.
- REQ-009: When the limit is exceeded, the server performs none of the side effects and responds with HTTP 429 and a human-readable German message saying to try again later. Rails' blank 429 is not used.
- REQ-010: Rate-limit counters live in the Rails cache store (`solid_cache` in production). They must not reset on deploy or differ between Puma workers.

### Cloudflare Turnstile on registration

- REQ-011: When both `TURNSTILE_SITE_KEY` and `TURNSTILE_SECRET_KEY` are set, the registration form renders the Turnstile widget. The widget must work on full page loads, Turbo visits, and after a 422 re-render.
- REQ-012: When Turnstile is enabled, registration create verifies the submitted token server-side against Cloudflare's siteverify endpoint, sending the secret and (optionally) the client IP. A missing, invalid, expired, or already-used token rejects the registration with HTTP 422, keeps the entered values, and shows a German message asking the person to complete the check again.
- REQ-013: Registration fails open when siteverify cannot be reached (network error, a timeout of about 5 seconds, a non-JSON or 5xx response), when Cloudflare reports `internal-error`, or when it reports a misconfigured secret (`invalid-input-secret` or `missing-input-secret`). In those cases the Turnstile check is treated as passed and a warning is logged without secrets or tokens. A misconfigured secret is logged at error level. Honeypot, timing, and rate-limit checks still apply.
- REQ-014: When either key is missing, Turnstile is disabled: the widget is not rendered and no verification happens. In production, a disabled Turnstile logs a warning at boot, once per process.
- REQ-015: The Turnstile secret is never rendered, logged, or sent to the browser. Only the site key is rendered.

### Ordering and side effects

- REQ-016: All spam checks run before any Devise action logic, so a rejected submission creates no `User`, `Business`, reset/confirmation/unlock token, account-email preview, `RegistrationMailer` notification, or Devise email.
- REQ-017: A submission that passes all checks behaves exactly as it does today, including the existing `PROD_SEND` and email-preview behavior.

### Observability

- REQ-018: Each rejection logs one line with the endpoint, the reason (`honeypot`, `timing`, `turnstile`, `rate_limit`), and the request ID. The log line excludes the submitted email, the honeypot content, the Turnstile token, and the password.

## Acceptance criteria

- AC-001: Given the registration form, when a human fills it normally after more than 3 seconds (with a valid Turnstile token if enabled), then the user and business are created, the admin notification is queued exactly once (with `PROD_SEND=true`), and the user is redirected to the confirmation-pending page, unchanged from today.
- AC-002: Given any protected form, when the honeypot field is non-empty, then no records, tokens, previews, or emails are created, and the response matches a successful submission for that endpoint (registration redirects to the confirmation-pending page; password/confirmation/unlock redirect as Devise does today).
- AC-003: Given any protected form, when it is submitted under 3 seconds after rendering, then the response is 422 with the form re-rendered, the generic retry message shown, non-secret values kept, and no records or emails created.
- AC-004: Given any protected form, when the timestamp field is missing, altered, signed for another purpose, or older than 24 hours, then the behavior matches AC-003.
- AC-005: Given 10 registration attempts from one IP within an hour, when an 11th is submitted, then it returns 429 with the German message and creates nothing. Requests from a different IP are unaffected.
- AC-006: Given 5 password-reset requests from one IP within 15 minutes, when a 6th is submitted, then it returns 429 and no reset email is sent. The same applies to confirmation resend and unlock resend.
- AC-007: Given Turnstile keys are configured, when the registration page loads (directly, via a Turbo visit, or after a 422 re-render), then the Turnstile widget renders and its token is submitted as `cf-turnstile-response`.
- AC-008: Given Turnstile keys are configured, when siteverify answers `success: false` or the token is missing, then registration returns 422 with the Turnstile message and creates nothing.
- AC-009: Given Turnstile keys are configured, when siteverify times out or returns 5xx, then registration proceeds if the other checks pass, and a warning is logged.
- AC-010: Given Turnstile keys are not configured, when the registration page loads, then no Turnstile script or widget is rendered and registration works with only honeypot, timing, and rate limit.
- AC-011: Given any rejection, then the log contains the reason and request ID, and no email address, token, honeypot content, or password.
- AC-012: Login, admin login, password change via reset token, and confirmation via token behave exactly as before. Existing tests keep passing.
- AC-013: Given a keyboard or screen-reader user, when they tab through any protected form, then focus never lands on the honeypot and it is not announced.

## Authorization

No roles or ownership change. All protected endpoints stay anonymous Devise endpoints. The spam checks are not an authorization boundary. Admin and member separation is unaffected. A rejected spam check never signs anyone in or reveals whether an account exists.

## Data and persistence

- No schema changes and no migrations.
- Rate-limit counters are short-lived cache entries in `solid_cache`. Each key contains the controller path and the client IP (Rails' `rate-limit:<controller>:<ip>` format), and the entry expires with the rate-limit window.
- No new user data is stored. The Turnstile token and honeypot value are never persisted.

## External side effects

- **Email**: Rejected submissions queue no `RegistrationMailer` notifications and no Devise mail (confirmation, reset, unlock). Successful submissions keep the current `PROD_SEND` gating and preview behavior.
- **Cloudflare siteverify**: one outbound HTTPS POST per registration submission while Turnstile is enabled. It is synchronous and limited to 5 seconds. Tokens are single-use: if the form fails validation for another reason, the re-rendered widget issues a new token.
- **Retries and duplicates**: a double submit of the same registration still hits the existing email uniqueness validation. Each attempt counts toward the rate limit.

## Security and privacy

- The honeypot is security by obscurity and only stops untargeted bots. Rate limiting caps volume. Turnstile protects the highest-value endpoint against smarter bots.
- The minimum-fill timestamp uses `Rails.application.message_verifier` (or an equivalent signed or encrypted message) with a dedicated purpose and expiry, so it cannot be forged or reused across purposes.
- The silent fake success on a tripped honeypot reveals nothing about account existence. It returns the same redirect as a normal submission for that endpoint.
- Rate limiting depends on `request.remote_ip`. Behind Dokploy/Traefik, Rails trusts private-range proxies by default. If production sees the proxy's IP for every request, all users would share one bucket, so this must be verified at rollout (see Compatibility).
- **Privacy/legal**: Turnstile loads a script from `challenges.cloudflare.com` and sends visitor and browser signals to Cloudflare. The app contains no privacy policy page. The client's privacy policy (wherever it is hosted) should mention Cloudflare Turnstile before the keys are enabled in production.
- **CSP**: none is enforced today, so the external script loads without policy changes. If a CSP is introduced later, it must allow `https://challenges.cloudflare.com` for `script-src` and `frame-src`.
- **Logging**: the Turnstile secret and token, honeypot content, and email addresses are never logged (REQ-018). The secret is read from ENV only.

## UI states

- **Normal**: no visible change except the Turnstile widget on registration when enabled. The widget is usually invisible or shows a small check, with no puzzle.
- **Timing or Turnstile failure**: 422 re-render with an inline alert above the form in the existing `role="alert"` style. Non-secret fields are preserved and passwords are cleared, as Devise does today.
- **Rate limited**: 429 page or re-render in the `auth` layout with a German message («Zu viele Anfragen. Bitte versuchen Sie es in einigen Minuten erneut.»).
- **Turnstile loading**: the submit button stays usable. If the token is not ready yet, the server rejects with the Turnstile message (AC-008).
- **Responsive**: the Turnstile widget (about 300px wide) must fit inside the registration card at 320px viewport width without horizontal scroll.
- **Keyboard and assistive technology**: see AC-013.

## Edge cases

- Password managers autofilling the email and submitting within 3 seconds on the short reset/resend forms: the timing check triggers a visible retry (not silent), so the user can submit again.
- Back navigation or Turbo cache restores a form with an old timestamp: anything younger than 24 hours passes. Older forms get the retry message and a fresh timestamp.
- A 422 re-render for an ordinary validation error (for example a taken email) must issue a fresh timestamp and reset the Turnstile widget, so the corrected resubmission isn't rejected as replay or too fast.
- Shared office or NAT IP with several legitimate members registering at once: the limit of 10 per hour is generous for this event's scale. Exceeding it shows a clear retry-later message.
- The browser blocks the Cloudflare script (ad blocker, privacy browser): the registration is rejected with the Turnstile message. This is an accepted trade-off of enabling Turnstile.
- Locale-prefixed routes (`/en/users`, …) share the same protections and rate-limit buckets.

## Compatibility / migration

- Additive only, with no data migration. Existing junk accounts are not cleaned up by this feature.
- Rollout: deploy with Turnstile keys unset (honeypot, timing, and rate limit active). Check in production logs that `request.remote_ip` shows real client IPs rather than the proxy IP. Then update the privacy policy, add `TURNSTILE_SITE_KEY` and `TURNSTILE_SECRET_KEY` in Dokploy, and redeploy.
- Rollback: unset the Turnstile keys to disable Turnstile instantly. The other checks roll back by reverting the code.
- New environment variables are documented in the README deployment section and `docs/security.md`.

## Out of scope

- Login brute-force rate limiting (Devise `:lockable` already locks accounts after failed attempts). This could be a follow-up.
- Cleanup of existing spam accounts and businesses.
- Devise `paranoid` mode or other account-enumeration changes on the reset and resend forms.
- A contact form (none exists).
- Rack-level or IP-reputation blocking (`rack-attack`, WAF, Cloudflare proxy).
- Turnstile on password reset, confirmation resend, or unlock resend (could be added later with the same component).

## Evidence

- `app/views/devise/sessions/_login.html.erb`: the sign-in page has no contact form. **CONFIRMED**
- `app/controllers/users/registrations_controller.rb`, `app/mailers/registration_mailer.rb`: registration queues the admin notification. **CONFIRMED**
- `app/models/user.rb`: Devise modules `:registerable, :recoverable, :confirmable, :lockable`. **CONFIRMED**
- `config/routes.rb`: `devise_for :users` inside the locale scope, with custom sessions/registrations/confirmations/passwords controllers. Unlocks use the default Devise controller. **CONFIRMED**
- `Gemfile`/`Gemfile.lock`: no spam or rate-limit gem. Rails 8.0 ships `ActionController::RateLimiting`. **CONFIRMED**
- `config/environments/production.rb`: `solid_cache_store`, Dokploy host. `config/environments/test.rb`: `null_store`. **CONFIRMED**
- `config/initializers/content_security_policy.rb`: no CSP enforced. **CONFIRMED**
- Production response headers (2026-11-14): no Cloudflare proxy headers. **INFERRED**: there's no Cloudflare in front, and `remote_ip` should come from Traefik's `X-Forwarded-For`.
- `test/controllers/registration_notification_test.rb`, `test/controllers/sessions_test.rb`: existing registration and login tests must keep passing. **CONFIRMED**
- Developer decision (2026-11-14): cover all mail-sending auth forms, using honeypot, timing, and rate limiting, plus Turnstile on registration. **CONFIRMED**

## Open questions

### BLOCKING

None.

### NON-BLOCKING

- Q1: Rate-limit thresholds. **Default**: registration 10 per hour per IP, other forms 5 per 15 minutes per IP. **Rationale**: well above legitimate use for a regional event, low enough to stop mail floods.
- Q2: Turnstile fail-open on Cloudflare outage. **Default**: fail open (REQ-013). **Rationale**: an attacker cannot cause a Cloudflare outage, the other checks remain, and registrations aren't blocked during outages.
- Q3: Privacy policy wording for Cloudflare Turnstile. **Default**: the client updates it before the keys are set in production. Turnstile stays disabled until then, because the code is gated on the keys.
- Q4: Minimum fill time. **Default**: 3 seconds on all protected forms.

## Requirement-to-verification matrix

| Requirement | Acceptance criteria | Verification approach |
|---|---|---|
| REQ-001, REQ-002 | AC-002–AC-006, AC-012 | Integration tests per endpoint; existing session/registration tests unchanged |
| REQ-003 | AC-013 | View assertions (`tabindex=-1`, `aria-hidden`, `autocomplete=off`); browser keyboard check |
| REQ-004 | AC-002 | Integration tests: no record, token, or email change; response equals the success redirect |
| REQ-005–REQ-007 | AC-003, AC-004 | Integration tests with time travel; tampered, wrong-purpose, missing, and expired tokens |
| REQ-008–REQ-010 | AC-005, AC-006 | Integration tests with a memory cache store for the limiter; different-IP isolation |
| REQ-011 | AC-007, AC-010 | View tests with and without keys; browser check of direct load, Turbo visit, and 422 re-render |
| REQ-012, REQ-013 | AC-008, AC-009 | Unit tests of the verifier with stubbed HTTP (success, failure, timeout, 5xx); integration test for the 422 path |
| REQ-014, REQ-015 | AC-010 | Unit/view tests; secret absent from rendered HTML |
| REQ-016, REQ-017 | AC-001, AC-002 | `assert_no_difference`, `assert_no_enqueued_emails`; existing `RegistrationNotificationTest` |
| REQ-018 | AC-011 | Log capture assertion in integration test |

## Final assessment

READY FOR PLANNING
