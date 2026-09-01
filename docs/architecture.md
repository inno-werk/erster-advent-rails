# Architecture

## Rails monolith

This project is a conventional Rails monolith. Use Rails' established conventions and the existing application structure.

The broad dependency direction is:

```text
routes → controllers → models/services/jobs → Active Record and external systems
```

- `config/routes.rb` defines endpoints, locale scope, and surface namespaces.
- Controllers handle HTTP concerns, strong parameters, authentication, record scoping, rendering, and redirects.
- Active Record models own associations, validation, persistence invariants, and cohesive state transitions.
- Service objects under `app/services` own multi-step domain behavior and external integrations that do not fit a model cleanly.
- Active Jobs under `app/jobs` make background execution explicit and must be retry-safe.
- Mailers own message composition; the delivery-mode decision remains centralized.
- ERB views present state. Durable business rules and authorization do not belong in templates.

Controllers may use Active Record directly where the current code does so clearly. Do not add repositories, commands, or interactors merely for architectural symmetry. Extract a service when behavior spans several records or an external system, needs a clear retry/idempotency boundary, or would otherwise make a controller/model incoherent.

## Application surfaces

The application has distinct surfaces:

- **Marketing** — public pages and publicly visible stores/products.
- **App** — authenticated member dashboard and current-year participation/business/print flows.
- **Setup** — onboarding screens under `App::Setup`, with a dedicated layout and stepper.
- **Admin** — back-office screens protected by the Admin login and role checks.
- **Authentication** — Devise registration, confirmation, recovery, and member/Admin sessions.
- **Checkout** — standalone simulated-payment confirmation; real Stripe payment collection is hosted by Stripe.

Namespace and layout boundaries are intentional. Do not select Setup versus App behavior with query parameters or expose authenticated behavior through Marketing routes. Reusable domain logic may be shared through models, services, or narrowly scoped concerns.

## Data and domain behavior

Active Record validations provide user-facing errors; durable uniqueness and integrity should also be represented in database constraints where practical. Use transactions and row locks for state transitions whose correctness depends on concurrent state, particularly participation upgrades and payment fulfilment.

The annual participation/print domain coexists with older `Product`, `Order`, and `Payment` tables. Do not infer that similarly named records are interchangeable. Read [`participation-and-print-materials.md`](participation-and-print-materials.md) before changing these areas.

Before schema changes, inspect `db/schema.rb`, all relevant migrations, current call sites, existing-row compatibility, nullability, uniqueness, indexes, dependent behavior, and rollback/rollout consequences. Prefer additive changes unless an explicit migration plan supports destructive work.

## Background work and external effects

Solid Queue is the Active Job backend. Production needs either `SOLID_QUEUE_IN_PUMA=true` or a separate `bin/jobs` process for queued work to execute. Jobs and the services they call must tolerate retries and duplicate delivery.

Stripe webhook receipt is deliberately separated from processing: the controller verifies and persists a unique event, then enqueues processing. Preserve this boundary. Email mode is checked both before enqueueing where applicable and at delivery time so queued messages cannot bypass a later safety setting.

## UI conventions

Reuse established ERB partials, layouts, Tailwind utilities, daisyUI components, Turbo behavior, and Stimulus controllers. Search for an equivalent UI before creating another pattern. Extract a partial/controller only when repeated structures represent the same concept or behavior.

Affected UI should account for applicable empty, validation, permission-denied, success, and failure states. Preserve field-level errors and accessible relationships such as `aria-invalid` and `aria-describedby` in authentication forms. Verify meaningful desktop, tablet, and mobile sizes in a browser; utility classes alone are not evidence. Consider keyboard and touch interaction.

Routes are locale-aware for German, English, French, and Italian. When a changed UI is translated, update and verify all applicable locale files and preserve locale through navigation and redirects.
