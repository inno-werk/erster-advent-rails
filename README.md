# README

## Development

To set up the development environment, follow these steps:

1. Clone the repository:
   ```bash
   git clone
   ```
2. Start the local database container:
   ```bash
   cd ./infrastructure/erster-advent
   docker-compose up -d
   ```
3. Run bundle install

   ```bash
   bundle install
   ```

   4. If not already done: Migrate DB.

   ```bash
   bin/rails db:migrate
   ```

   5. For a fresh disposable database only: seed the base shops and accounts.
      **Warning: this deletes existing users, shops, orders and CMS content.**

   ```bash
   bin/rails db:seed
   ```

### Add demo activity to existing shops

To populate the admin membership/payment and print-order screens without
replacing shops, accounts or existing records:

```bash
bin/rails print_materials:seed # Only needed if the print catalogue is empty.
bin/rails demo_data:seed
```

This development/test-only task adds five years of varied memberships, simulated
payments, pending/paid upgrades and print orders for existing active shops.
It preserves existing user/year records, shop details, passwords, roles, images,
catalogue entries and distribution dates. Reruns do not duplicate or reset data.
Added payments use the dummy provider and `DEMO-...` references; no money moves
and no emails are sent. Some shops intentionally have no current membership or
an empty/missing order, so those dashboard states remain available for testing.

Optional: `YEAR=2026 YEARS=3 bin/rails demo_data:seed` limits the history. Do not
use the destructive `db:seed` command to add activity to an existing database.

## Live server

To do live development, you need to do those 3 steps:

```bash
# Rails dev server
bin/dev
```

To run commands in the docker container, you must be on /rails

## Tools

To find formatting issues, run:

```bash
erb-format {path to file}
```

**credentials**
email: superadmin@example.com
pw: superadmin@example.com

## Dev Database

credentials for local dev database:

- host: localhost
- port: 5432

- database: dev_db
- user: postgres
- password: postgres

## Deployment

For annual membership, print-material setup, rollout implications and future
payment integration, see [Participation and print materials](docs/participation-and-print-materials.md).

The app is deployed to [Dokploy](https://dokploy.com) from the `Dockerfile`. Set the
variables below in the app's **Environment** tab.

Note that `dotenv-rails` is not installed — a `.env` file in the project is _not_
loaded by the app. Everything has to come from the real environment.

This app uses **environment-scoped credentials** (`config/credentials/production.yml.enc`),
not the default `config/credentials.yml.enc`. There is no `config/master.key`. The value
for `RAILS_MASTER_KEY` is therefore the contents of `config/credentials/production.key`.
Using a key from a different project or a different Rails app produces
`ActiveSupport::MessageEncryptor::InvalidMessage` at boot.

To check a key without booting the app or connecting to the database:

```bash
RAILS_MASTER_KEY=<candidate-key> bundle exec ruby -e '
require "active_support"
require "active_support/encrypted_configuration"
puts ActiveSupport::EncryptedConfiguration.new(
  config_path: "config/credentials/production.yml.enc",
  key_path: "config/credentials/production.key",
  env_key: "RAILS_MASTER_KEY", raise_if_missing_key: true).read'
```

### Required

| Variable           | Description                                                                                                                                                         |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `RAILS_MASTER_KEY` | Contents of `config/credentials/production.key`. Decrypts `config/credentials/production.yml.enc` and provides `secret_key_base`. The app will not boot without it. |
| `PGHOST`           | Postgres host. On Dokploy this is the internal service name of the database container.                                                                              |
| `PGPORT`           | Postgres port, defaults to `5432`.                                                                                                                                  |
| `PGUSER`           | Postgres user, defaults to `postgres`.                                                                                                                              |
| `PGPASSWORD`       | Postgres password, defaults to `postgres`.                                                                                                                          |
| `PGDATABASE`       | Database name. **No default in production** — must be set explicitly.                                                                                               |

`config/database.yml` points the `primary`, `cable`, `queue` and `cache` databases at the
same `PGDATABASE`, so Solid Queue / Cache / Cable tables live alongside the app tables.

Do not set `DATABASE_URL`. Rails would apply it to the `primary` database only and leave
the other three on the `PG*` values.

### Active Storage (S3)

`config.active_storage.service = :amazon` is set in production, so uploads fail without
these. The bucket name is built as `#{APP_NAME}-#{Rails.env}` in `config/storage.yml`.

| Variable        | Description                                                                                        |
| --------------- | -------------------------------------------------------------------------------------------------- |
| `APP_NAME`      | Bucket name prefix. Must match the real bucket, i.e. `ersteradvent` for `ersteradvent-production`. |
| `S3_KEY_ID`     | Access key ID of an IAM user scoped to that bucket.                                                |
| `S3_ACCESS_KEY` | Secret access key for the same user.                                                               |
| `S3_REGION`     | Bucket region, e.g. `eu-west-1`. Defaults to `us-east-1`.                                          |

The IAM user only needs `ListBucket` / `GetBucketLocation` on the bucket and
`GetObject` / `PutObject` / `DeleteObject` plus the multipart actions on its contents.
Avoid attaching `AmazonS3FullAccess`, which would also expose the unrelated backup
buckets in the same account.

Uploads are proxied through the Rails server (no `direct_upload`), so the bucket does not
need a CORS configuration.

### Optional

| Variable              | Description                                                                                                                                                                                                                                                                                                        |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `ALLOWED_HOSTS`       | Comma-separated extra host names accepted by DNS-rebinding protection, on top of the `erster-advent-bern.ch` / `.coffee-journal.com` domains hardcoded in `production.rb`. Needed when reaching the app on a Dokploy-generated domain or a bare IP — otherwise every request is rejected with `403` in middleware. |
| `SOLID_QUEUE_IN_PUMA` | Set to `true` to run the Solid Queue supervisor inside Puma. Without it, no background jobs are processed, since there is no separate worker container.                                                                                                                                                            |
| `JOB_CONCURRENCY`     | Solid Queue processes, defaults to `1`.                                                                                                                                                                                                                                                                            |
| `WEB_CONCURRENCY`     | Puma workers.                                                                                                                                                                                                                                                                                                      |
| `RAILS_MAX_THREADS`   | Puma threads and DB pool size, defaults to `10`.                                                                                                                                                                                                                                                                   |
| `RAILS_LOG_LEVEL`     | Defaults to `info`.                                                                                                                                                                                                                                                                                                |
| `SMTP_USERNAME`       | SMTP authentication username (the full Gmail address when using Gmail).                                                                                                                                                                                                                                                                              |
| `SMTP_PASSWORD`       | SMTP password.                                                                                                                                                                                                                                                                                                     |
| `SMTP_ADDRESS`        | Defaults to `smtp.gmail.com`.                                                                                                                                                                                                                                                                                      |
| `SMTP_PORT`           | Defaults to `587`.                                                                                                                                                                                                                                                                                                 |
| `SKIP_DB_PREPARE`     | Set to `true` to skip `db:prepare` on boot.                                                                                                                                                                                                                                                                        |
| `DB_PREPARE_RETRIES`  | Boot-time `db:prepare` attempts, defaults to `5`.                                                                                                                                                                                                                                                                  |

`RAILS_ENV` and the `BUNDLE_*` variables are already baked into the `Dockerfile` and do
not need to be set.

### Gmail for test delivery

Gmail sends real emails; it is not a sandbox. Enable Google 2-Step Verification and
create an [App Password](https://myaccount.google.com/apppasswords) for this app.
A connected Gmail account in a coding assistant does not provide SMTP credentials
for the Rails application.

Set these variables in the deployment environment (do not commit credentials):

```dotenv
SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your-account@gmail.com
SMTP_PASSWORD=<Google App Password>
SMTP_FROM=your-account@gmail.com
PROD_SEND=true
```

`SMTP_FROM` sets the sender for account emails and admin notifications. If unset
or blank, it defaults to `Erster Advent Bern <info@erster-advent-bern.ch>`.
The admin notification recipient remains `info@erster-advent-bern.ch`.
`PROD_SEND=true` enables both account emails and admin new-shop notifications.
Real delivery is disabled by default; no second email-mode variable is needed.

Restart the app and any separate email workers after changing the environment.
These SMTP settings apply in production; local development still uses
`letter_opener` browser previews. A local `.env` file is not automatically loaded.

### Email previews on a deployed test instance (no SMTP required)

To test registration without a mail provider, explicitly set:

```dotenv
PROD_SEND=false
```

Restart the app and any separate workers. A new registration then shows
**E-Mail-Vorschau öffnen** directly in the confirmation panel. The separate preview contains the actual account
email and working confirmation link, with a clear notice that nothing was sent.
Links point to the deployment where the preview is opened.

- `PROD_SEND` is the only email-mode variable: `false` enables private previews
  without sending; `true` enables account and admin emails through the configured
  delivery method. Queued messages check the same flag before delivery.
- If unset, `PROD_SEND` defaults to `false`: sending remains off and new test
  registrations get private previews. Blank or invalid values disable both modes.
  Always set `PROD_SEND=true` explicitly for real users.
- Previews are limited to regular accounts newly registered in the same browser
  session and expire 30 minutes after registration. Resent confirmations and
  password resets can be previewed only for that account within that window.
  Registrations made before preview mode was enabled have no stored preview;
  use a fresh test registration to test the preview flow.
- Existing accounts and admin accounts cannot have recovery emails previewed by
  entering their address. Their recovery emails are also suppressed in preview
  mode: use real SMTP delivery for those accounts.
- Logging out removes preview access. URLs contain no mailbox IDs or email tokens;
  access requires the originating session. Email content is encrypted in the
  existing shared Rails cache and responses are marked `no-store`.

**Use only for a test/demo deployment and test accounts.** A confirmation clicked
in a browser preview does not prove mailbox ownership. For actual users, set
`PROD_SEND=true`, configure SMTP, and restart. Production's configured Solid Cache
must be available. The regular application migrations create and index
`solid_cache_entries` in the shared PostgreSQL database; no separate service is
required.

### Repairing a missing Solid Cache table or index

`ArgumentError: No unique index found for key_hash` during registration means
Solid Cache cannot find its required unique index. The cache table may also be
missing entirely. This deployment shares one PostgreSQL database across primary,
queue, cable and cache connections; having `db/cache_schema.rb` in the repository
does not apply it to an already initialized database.

Deploy the migration `20260828170000_add_solid_cache_entries.rb`. The normal
container startup runs `bin/rails db:prepare` and applies it. If database preparation
is disabled, run this in the updated application container:

```sh
RAILS_ENV=production bin/rails db:migrate
```

Then restart the application and workers so they discard old schema caches. The
migration creates the cache table if missing and repairs its indexes without
replacing existing rows. Do not use `db:cache:schema:load` to repair an existing
database: schema loading can replace the cache table.

A preview-cache failure no longer turns a saved registration into a 500. It keeps
session ownership, shows a retry message, and logs a sanitized cache diagnostic.
Once the database is repaired, request the confirmation again in the same browser
within the 30-minute window. Attempts that failed before this fallback was deployed
may already have created an account without retaining preview access; use a fresh
test address or the normal email confirmation flow with SMTP enabled.

### Container notes

- The image starts via Thruster and exposes port **80** — point the Dokploy port mapping there, not at 3000.
- `bin/docker-entrypoint` runs `db:prepare` with retries before boot, so the app tolerates the database not being ready yet.
- `force_ssl` and `assume_ssl` are enabled in production. HTTPS must be enabled for the domain in Dokploy so Traefik terminates TLS and forwards `X-Forwarded-Proto`; otherwise requests end in a redirect loop.
- The app and the Postgres service must be in the same Dokploy project, otherwise `PGHOST` will not resolve.
