# AGENTS.md

This file is the repository constitution and entry point for every coding agent. It contains the rules that must be visible before work starts. Canonical phase workflows and deeper project knowledge live under [`docs/`](docs/README.md).

## Project

- Runtime: Ruby 3.3.0 and Node.js 23.10.0
- Framework: Ruby on Rails 8.0.2.1
- Database: PostgreSQL with Active Record
- Views and styling: ERB, Hotwire (Turbo and Stimulus), Tailwind CSS 4, and daisyUI 5
- Authentication: Devise 4.9.4
- Files: Active Storage, with S3-compatible storage in production
- Background work: Active Job with Solid Queue
- Payments: Stripe 19.4, plus an explicitly enabled dummy flow
- Tests: Rails Minitest, Capybara/Selenium system tests, and Node's test runner for JavaScript
- Deployment: Docker/Dokploy; Kamal configuration also exists

Important commands:

```bash
bin/dev
bin/rails test
bin/rails test:system
node --test test/javascript/*_test.mjs
bin/rubocop
bin/brakeman --no-pager
```

For non-trivial implementation work, run at least `bin/rails test`, `bin/rubocop`, and `bin/brakeman --no-pager`, plus relevant JavaScript/system tests and browser verification when applicable.

## Working principles

### Investigate before asking

Search the repository before asking the developer. Inspect relevant routes, controllers, models, services, jobs, mailers, views, tests, schema, migrations, configuration, documentation, and git history. Prefer repository evidence and established patterns over guesses or new abstractions.

### Handle uncertainty explicitly

Classify important conclusions as:

- **CONFIRMED** — supported by requirements or authoritative evidence.
- **INFERRED** — strongly implied by existing behavior or patterns.
- **ASSUMED** — selected because evidence is unavailable.

Do not silently make material assumptions. Ask before an assumption changes authentication, authorization, sensitive data, destructive behavior, money, contracts, legal behavior, important external communication, irreversible migrations, or a core user workflow. For low-risk ambiguity, choose and record the most conservative reasonable default.

### Keep scope disciplined

Implement the smallest coherent change that satisfies approved requirements. Do not refactor, rename, reformat, or abstract unrelated code. Preserve user changes in a dirty worktree. Report unrelated defects separately unless they block correct implementation.

## Workflow routing

Choose the lightest workflow proportionate to the task:

```text
TRIVIAL
→ IMPLEMENT

STANDARD
→ SPEC → PLAN → IMPLEMENT → REVIEW

HIGH RISK
→ SPEC → PLAN → independent plan review
→ IMPLEMENT → independent REVIEW
```

High-risk work includes authentication, authorization, sensitive personal data, payments, contracts, destructive migrations, important external communication, and irreversible operations. This routing is guidance, not bureaucracy: tiny, low-risk changes do not need artificial artifacts.

The canonical, agent-agnostic phase instructions are:

- [`SPEC`](docs/agent-workflows/spec.md) — turn a request into implementation-ready requirements.
- [`PLAN`](docs/agent-workflows/plan.md) — design and verify the implementation approach.
- [`IMPLEMENT`](docs/agent-workflows/implement.md) — execute an approved plan and verify it.
- [`REVIEW`](docs/agent-workflows/review.md) — independently test the result against requirements.

Approved feature specifications live in [`docs/features/`](docs/features/README.md).

## Architecture

This project is a conventional Rails monolith. Preserve the dependency direction:

```text
routes → controllers → models/services/jobs → Active Record and external systems
```

- Routes define HTTP endpoints and namespace boundaries.
- Controllers translate HTTP input/output, enforce authentication and record scope, and orchestrate application behavior.
- Models own associations, validations, persistence invariants, and cohesive domain transitions.
- Services own multi-step behavior and external integrations that do not fit one model cleanly.
- Jobs make background execution explicit and must remain safe under retries.
- Views present state and must not contain authorization or durable business logic.

Do not add repository or command layers merely to imitate another architecture. Reuse the established Rails pattern unless the change has a concrete need for another seam.

Marketing, App, Setup, Admin, authentication, and Checkout are separate presentation surfaces with their own controllers/layouts. Do not expose App or Admin functionality through Marketing routes. Setup-specific screens stay under `App::Setup`; shared domain behavior may remain in models, concerns, or services.

Follow established Tailwind/daisyUI, ERB, Turbo, and Stimulus patterns. See [`docs/architecture.md`](docs/architecture.md) for structure and UI guidance.

## Authorization and security

- Devise authentication is the account boundary. App controllers require an authenticated user; Admin controllers require `adminish?`; Superadmin-only actions must retain their narrower check.
- Scope member-owned records through `current_user` and the active event year. Never trust submitted owner IDs or use UI visibility as an authorization boundary.
- Use strong parameters and model validations. Add database constraints for durable invariants where practical.
- Keep Rails CSRF protection enabled. The Stripe webhook is the deliberate exception and must retain signature verification before accepting an event.
- Consider authentication, authorization, ownership/IDOR, CSRF, SQL/HTML injection, unsafe redirects, output escaping, information leakage, signed-token expiry/replay, race conditions, duplicate submissions, file access, logging, and retry behavior.
- External side effects such as email, payments, files, webhooks, and jobs must be designed for retries and duplicate execution.
- Never log credentials, Devise tokens, Stripe secrets, signed payment quotes, or sensitive personal values unnecessarily.

Security invariants are non-negotiable:

- Only a verified Stripe webhook may mark a real Stripe payment paid. A Checkout success redirect is informational, not proof of payment.
- Stripe event IDs and local idempotency keys remain unique. Amount, currency, local obligation, and ownership must match before fulfilment.
- Dummy payment is available only through the explicit `PROD_PAYMENT` rules and must remain visibly marked as simulated.
- Active Storage uploads use the configured private service. Do not place protected uploads under `public/` or bypass authenticated Rails access with public object URLs.
- `PROD_SEND=true` is required for real email delivery. Preview mode must not send mail or expose another user's message or account token.

See [`docs/security.md`](docs/security.md), [`docs/stripe-integration.md`](docs/stripe-integration.md), and [`docs/participation-and-print-materials.md`](docs/participation-and-print-materials.md).

## Stable domain invariants

- A user has at most one `Participation` and one `PrintOrder` per event year. `PARTICIPATION_YEAR`, falling back to the current year, selects the active event.
- Participation prices are snapshotted in CHF cents. A paid category/amount cannot be edited directly; a valid paid upgrade applies the higher category atomically.
- Public business visibility requires an active user and an admin-confirmed business. Payment status does not affect listing. The `no_listing` tier is never public: a current-year «Kein Eintrag» membership is an explicit opt-out and hides the business.
- Payment transitions must remain server-calculated, locked, retry-safe, and idempotent. Never accept a client-supplied price, paid state, payment owner, or success query parameter as authority.
- Print-product availability controls new selection, but disabling a product must not erase historical order items. Member quantities, deadlines, user ownership, and event year are enforced server-side.
- Legacy `Product`, `Order`, and `Payment` records are not interchangeable with annual `Participation`, `PrintProduct`, `PrintOrder`, or `StripePayment` records.
- Admin, member, and public behavior remain separate. Member credentials cannot establish an Admin session, and hidden navigation does not grant or revoke access.
- `PROD_SEND` is the only email-mode switch. Already queued mail must re-check delivery mode before sending.

Detailed behavior is documented in:

- [`Participation and print materials`](docs/participation-and-print-materials.md)
- [`Stripe integration`](docs/stripe-integration.md)
- [`Business and product processes`](docs/prozesse.md)

Treat documents explicitly marked as drafts or plans as context, not proof that behavior is implemented. Verify them against code and tests.

## Data, UI, and external behavior

- Inspect `db/schema.rb`, migrations, existing rows, nullability, uniqueness, indexes, locks/transactions, dependent behavior, and rollout implications before database changes. Prefer additive, backwards-compatible migrations and database constraints for important invariants.
- Never use the destructive `db:seed` task merely to add demo activity to an existing database. Use the documented narrow tasks where applicable.
- For email and other external actions, identify the trigger, recipients, payload/template, delivery mode, failure handling, duplicate prevention, and audit requirements. Avoid important side effects on GET requests or page refresh.
- Reuse existing UI patterns and Tailwind/daisyUI utilities. Account for empty, loading, validation, permission-denied, success, and failure states where relevant. Verify meaningful responsive and keyboard/touch behavior in a browser for affected UI.
- Preserve locale-aware routes and translations across German, English, French, and Italian where affected.
- Update project documentation when work introduces a lasting invariant, integration, environment variable, operational requirement, architectural decision, or non-obvious workflow.

## Definition of done

Before claiming completion:

1. Re-read the request, approved specification, plan, and acceptance criteria.
2. Inspect the complete git diff and surrounding code.
3. Confirm authentication, authorization/ownership, validation, failure paths, data integrity, and retry/duplicate behavior where relevant.
4. Run proportionate automated verification. For non-trivial changes, run `bin/rails test`, `bin/rubocop`, and `bin/brakeman --no-pager` at minimum.
5. Run relevant JavaScript/system tests and browser verification for user-facing behavior.
6. Confirm no unrelated behavior changed and remove temporary code or logging.
7. Report completed behavior, evidence for each acceptance criterion, assumptions/deviations, and anything not verified.

Never weaken or remove tests merely to make a change pass. A boot or syntax result alone is not proof that a user workflow works. Prefer a simple, verified solution that follows existing conventions.
