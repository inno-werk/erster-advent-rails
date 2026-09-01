# Stripe integration

The Stripe implementation planner generated guide `iguide_61VJoLtfMZQS2jxan41EWqE8ut7oD`
for the Erster Advent Sandbox. It recommends Stripe-hosted Checkout for one-time
CHF payments. Annual participation is not a subscription. An upgrade is a second
payment for the positive difference between the old and new fee.

## Ownership boundary

- Rails owns the event year, category, amount, upgrade calculation and participation state.
- Stripe owns collection of the payment method and payment.
- Only a signed Stripe webhook may move a participation or upgrade to `paid`.
- A browser return from Checkout is informational and never confirms payment.

## Implemented foundation

- `StripePayment` records immutable local obligations, attempts and Stripe references.
- Checkout uses `mode: payment`, CHF, server-side amounts, customer email, opaque IDs in metadata and a stable idempotency key.
- Payment methods remain dynamic and are controlled in Stripe, allowing cards and TWINT without code changes.
- Signed events are deduplicated in `StripeWebhookEvent` and processed with Active Job.
- Initial payments and upgrade differences are fulfilled under database locks.
- Amount, currency and local ownership are checked before fulfilment.
- Expired, delayed and failed Checkout states are recorded without activating participation.
- The existing dummy adapter remains available only when explicitly enabled.

## Required deployment configuration

Set `STRIPE_SECRET_KEY` and `STRIPE_WEBHOOK_SECRET` in the deployment secret store.
Use separate sandbox and live values. The production service should use a restricted
key with only the permissions needed to create/read Checkout Sessions and read their
PaymentIntents. Never put either secret in source control, frontend code, logs or error
reports.

Register `https://www.erster-advent-bern.ch/stripe/webhooks` and the event list in
the README. Run Solid Queue in production so accepted events are processed.

## Follow-up phases

1. Create one annual Stripe Product and immutable Prices for the standard tiers;
   retain dynamic server-side `price_data` only for irregular upgrade differences.
2. Add refund and dispute event handling plus administrator review states.
3. Add daily reconciliation for obligations, payments, fees, refunds and payouts.
4. Pilot in sandbox with card, TWINT, 3DS, failures, duplicate/out-of-order events,
   expired sessions and upgrades before enabling a small production cohort.
5. Confirm VAT treatment with the Verein's accountant before enabling Stripe Tax.
6. Ensure the public website shows the complete legal name, street address and
   contact details required for TWINT approval.
