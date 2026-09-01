# Security

Security is a design input for every relevant change, not a final checklist. Explicitly determine who may act, which records they may act on, who may read the result, who must be denied, and what a denial reveals.

## Authentication and authorization

Devise provides account authentication, confirmation, lockout, recovery, tracking, and remember-me behavior. Preserve those controls when customizing controllers or failure handling.

Authorization is currently role- and ownership-based:

- App controllers authenticate a user through `App::BaseController`.
- Admin controllers require `current_user.adminish?` through `Admin::BaseController`.
- Superadmin-only operations must also check `superadmin?`; Admin access alone is insufficient.
- Member-owned records must be loaded through `current_user` associations and the applicable active year. A submitted ID is never proof of ownership.

Presentation may hide unavailable actions, but templates and navigation are never enforcement boundaries. Member credentials must not authenticate through the Admin login flow.

## Payments and webhooks

Rails owns the participation category, event year, CHF amount, upgrade difference, local obligation, and paid state. Never trust prices, ownership, payment status, or redirect targets submitted by the browser.

Only a Stripe event whose signature is verified with `STRIPE_WEBHOOK_SECRET` may fulfil a real Stripe payment. Checkout return URLs and `status=success` parameters are informational. Before fulfilment, match the unique local payment, Checkout reference, amount, currency, and target; perform state changes under the existing locks/transaction.

Webhook event IDs and payment idempotency keys remain unique. Receipt and processing must tolerate duplicates, retries, failures, and out-of-order delivery. The webhook route is the deliberate CSRF exception; do not broaden `skip_forgery_protection` to browser actions.

The dummy checkout is a simulation that can activate real local participation records. It must stay behind the exact `PROD_PAYMENT` rules, use expiring signed quotes bound to the current user/participation/upgrade/amount/version, change state only on POST, and remain visibly identified as simulated.

## Email and account tokens

`PROD_SEND=true` is the sole opt-in for real account and registration email delivery. Preview mode must never contact SMTP. Already queued messages must re-check delivery mode before sending.

Email previews may contain real Devise account links. Access must prove the current session's ownership, remain time-limited as implemented, and never expose message content or tokens through cross-tab notifications, logs, analytics, or another user's session. Authentication errors should remain generic where detail would reveal whether an account exists.

Do not log passwords, password digests, Devise tokens, preview contents, SMTP credentials, Stripe secrets, webhook signatures, or signed payment quotes. Keep sensitive parameters covered by Rails parameter filtering.

## Files and personal data

Active Storage manages business and print-product images. Production uses the private configured S3-compatible service; credentials must be narrowly scoped to the application bucket. Do not place uploads under `public/`, construct storage paths from client filenames, or introduce public object access without an explicit reviewed requirement.

Validate applicable file type and size at the model boundary and authorize attachment create/delete/read actions through the owning record. Member image actions stay scoped to the current user's business; Admin access remains separately enforced.

## Threat review

For security-relevant work, consider:

- authentication, confirmation, lockout, session fixation, and session behavior;
- role authorization, record ownership, IDOR, and denied paths;
- CSRF, SQL/HTML injection, output escaping, mass assignment, and unsafe redirects;
- signed-token purpose, entropy, scoping, expiry, enumeration, and replay;
- information leakage through errors, views, email previews, logs, URLs, exports, and analytics;
- file type/size/path validation and protected access;
- duplicate submissions, race conditions, locks, transactions, and database constraints;
- webhook authenticity, external retries, idempotency, and partial failure.

Never weaken an existing control merely to make implementation easier.

## Operational requirements

Security-relevant configuration includes:

```text
RAILS_MASTER_KEY       Decrypts production credentials
STRIPE_SECRET_KEY      Server-side Stripe API credential
STRIPE_WEBHOOK_SECRET  Verifies webhook authenticity
PROD_PAYMENT           Selects explicit dummy/real payment behavior
PROD_SEND              Exact true/false email delivery or preview behavior
S3_KEY_ID              Active Storage access-key ID
S3_ACCESS_KEY          Active Storage secret access key
S3_REGION              Storage region
APP_NAME               Storage bucket prefix
```

Keep secrets out of source control, frontend code, logs, and error reports. Use separate sandbox and live Stripe credentials and replace the API and webhook secrets together when changing environments.
