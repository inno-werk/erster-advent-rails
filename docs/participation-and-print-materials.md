# Annual participation and print materials

## Existing architecture and migration decision

Rails 8 / PostgreSQL, Devise (including email confirmation), role-based Admin
authorization, separate Admin and Store layouts, Tailwind/daisyUI, Hotwire,
Action Text and Active Storage remain in use. A User owns one Business; the
existing `Business.status` enum controls administrative confirmation. The older
`confirmed` boolean was not the public query's source of truth and remains intact.

The legacy Product, Order and Payment records describe seller-owned merchandise,
prices, sizes, single-product orders and uploaded payment proof. Local development
already contained data in all three tables. They cannot safely be interpreted as
annual participation or free print allocations, so they are preserved unchanged.
The new domain has explicit names rather than overloading incompatible columns.
CMS models, controllers and views are unchanged.

## Deployment and configuration

Run the additive migration and the narrowly scoped initial-data task:

```sh
bin/rails db:migrate
bin/rails print_materials:seed
```

`print_materials:seed` creates the poster, postcard and city-map bundles by stable
seed keys. Repeating it does not duplicate products or overwrite admin edits.
It also removes the old «Gratis.» suffix only when an existing description
exactly matches the original seed text. Custom descriptions remain unchanged.
Do **not** use the existing `db:seed` for a live database: its pre-existing demo
workflow clears data, including users and CMS content.

Set `PARTICIPATION_YEAR` to the year currently open for participation. Without an
override, `EventConfiguration.year` uses `Date.current.year`.
Admins set the distribution date and order deadline at `/admin/print_products`;
no deployment or environment change is needed for those dates. They are stored in `PrintDistribution`
per event year, so a previous year's date never appears in a new event. Clearing
the date shows «Das Datum wird noch bekannt gegeben» to members. The print-order
delivery block shows the configured weekday and distribution date together with
the order deadline; missing values retain explicit announcement placeholders.
The order deadline is inclusive through the end of the selected day in
`Europe/Zurich`. A blank deadline leaves ordering open. The deadline cannot be
later than the distribution date. After it passes, member edit and update routes
redirect to the summary without saving anything; admin corrections remain available.
These are real process environment variables; the project does not load `.env`.
Restart the application after changing them. Missing custom configuration (including
Rails' empty `OrderedOptions` placeholder) falls back to the environment/current
year, never to a blank database year or a displayed `{}`.

**Rollout consequence:** existing confirmed businesses have no annual participation
record and therefore disappear from public listings until they select a current
category and an admin confirms payment. Legacy payment proof is not automatically
converted into a current-year paid membership: neither year nor category/amount
can be inferred safely. Plan that operational transition before production deploy.

## Annual participation

`Participation` belongs to User because business details are completed after
membership selection. A database unique index enforces one record per user/year.
The record stores category, amount in CHF cents, selected time, payment status,
paid time, and optional future provider/reference. Amount is snapshotted only on
creation/category change, so unrelated saves and future prices do not reprice
history. Direct paid category/amount changes and owner/year reassignment are
rejected; a confirmed upgrade is the only path to a higher paid category.

The hard-coded categories are `leist_member` (CHF 200), `non_leist_member`
(CHF 250), and `no_listing` (CHF 100). Completion is derived from payment status
`paid`; it is not a permanent flag on User or Business. `pending` has no paid date.
Old annual records remain stored and visible in admin histories; the member
dashboard shows only the active year's status.

Paid memberships offer «Mitgliedschaft erhöhen» only from CHF 100 to CHF 200 or
CHF 250. Neither listed category can change after payment. `ParticipationUpgrade` snapshots the existing
paid category/amount, target category/amount and their difference in cents. Existing
paid rows need no backfill: their stored amount is the credit. One pending upgrade
per participation is enforced by a partial unique index and row locks; repeated
requests for the same pending upgrade reuse it. Other changes wait until that
upgrade is settled. Lower/equal categories and submitted price/payment fields
cannot create discounts or mark an upgrade paid.

The original paid membership and its listing/editing rights remain active until
the difference is confirmed. An upgrade from «Kein Eintrag» unlocks business editing
and listing eligibility only after payment confirmation. Confirmation atomically
applies the quoted category/amount and records the upgrade payment; repeated
confirmation is a no-op. Previously created pending CHF 200 → 250 upgrades remain
stored but cannot be paid through admin or test payment actions. The original
paid timestamp stays intact, while the UI shows the latest confirmed payment.

`Business.publicly_visible` requires the existing confirmed status, a non-deleted
user, and a paid participation for the active year in one of the two listed
categories. All public store lists, search, detail access, homepage features and
store counts use it. Category C is excluded in SQL even if paid. Future map or
printed-map exports must use the same eligibility rule.

## Flow and access

Self-registration creates the account and a pending business together, using the
entered business name, phone, address, contact name and email. The address also
prefills the billing address. Invalid business details prevent both records from
being saved; the business remains unpublished until the normal approval and
participation requirements are met. Registration still uses Devise email confirmation. Confirmation leads to
`/app/setup/participation`, which begins a separate setup layout without the
dashboard sidebar. `/app/setup` is also an entry point for membership selection. Subsequent incomplete logins lead to `/app/participation`, a
status-only dashboard page with a membership-selection or pending-payment CTA.
Every Store page requires login. Navigation shows an attention icon at
«Mitgliedschaft» while participation/payment is outstanding, and at
«Mein Geschäft» while the business is not approved. Payment details appear only
on the participation page; approval information appears only on the business
summary. There are no global status banners. Account editing remains available
regardless of membership. Business editing is available before payment for tiers
with a listing (and before a membership is selected).
The current year's «Kein Eintrag» membership overrides the business summary and
approval notice with an explanation that no public listing or business editing
is included. Its approval warning icon is suppressed. All member business write
actions, including creation and image removal, redirect to that explanation;
existing data is preserved and admin editing remains available. Initial setup
skips business editing for this tier. Changing an unpaid membership to a listed
tier restores editing; last year's category does not restrict the current year.
Unpaid memberships also offer «Mitgliedschaft ändern». This opens the existing
dashboard category form, without the onboarding stepper; saving returns to
the membership summary. Paid memberships expose higher-tier upgrades, or
«Differenz bezahlen» when an upgrade is pending, and reject direct category edits.

The member sidebar contains «Mitgliedschaft», «Meine Printbestellung»,
«Mein Geschäft» and «Kontoeinstellungen». «Mein Geschäft» opens the business overview;
«Informationen bearbeiten» in its fixed top bar opens the editor. Both views keep
the same navigation entry active. Complete memberships also land on the overview
after login. Memberships without a listing retain the explanation screen. Business status uses the
approval information only, without a duplicate badge.

Account settings use the dashboard layout and open as a read-only overview.
Personal details and password have separate editors: name, phone and email can be
updated without a password, while password changes require the current password.
Email changes retain Devise reconfirmation. The two endpoints use independent
strong-parameter allowlists so one cannot modify the other's fields. Self-service
account deletion flags the user as deactivated, signs out the current session and
preserves all account, participation, payment and order data. Deactivated users
cannot authenticate and their businesses are excluded from public visibility.
Signup retains the separate auth layout.

Admin login uses GET/POST `/admin/login`, separately from the member login at
`/users/sign_in`. Both use the same auth layout and form design, with an explicit
«Admin-Login» heading for administrators. Login errors appear inline on the
originating form; inactive-admin failures also return to the admin login.
Devise password verification, lockouts, confirmation and remember-me behavior
remain active. Member credentials cannot establish a session through admin login.
Anonymous visits to protected admin pages go to the admin login; signed-in members
remain blocked. Registration links are absent from login and account recovery
screens, while the direct `/users/sign_up` URL remains available for distribution.
This hides public signup navigation; it does not introduce invitation tokens.
Restart the Rails server after deploying the Devise failure-handler configuration.

Setup has dedicated controllers under `App::Setup`, its own screen templates under
`app/views/app/setup`, and a single stepper rendered by `layouts/setup`. Dashboard
controllers use the app layout, except for the standalone test checkout; the old `setup` query parameter no longer
selects screens or controls navigation. Reusable layout components, models and
signed test-payment processing remain shared, not the setup screens. Both test-payment
entry points leave their originating layout for the same standalone checkout.

| Setup route | Purpose |
| --- | --- |
| `/app/setup/participation` | Select and save the current annual membership. |
| `/app/setup/payment` | Pay now or continue without payment. |
| `/app/setup/payment?status=success` | Confirm recorded payment on the same step. |
| `/app/setup/test_payment` | Mock payment confirmation when test mode is enabled. |
| `/app/setup/print_order` | Select product quantities and continue. |
| `/app/setup/business` | Short handoff to «Mein Geschäft» in the app. |

The payment introduction names the chosen membership, event year and amount due,
without a separate membership details block. Both below the price and in the bottom
bar, it offers «Jetzt bezahlen» (primary) and «Später bezahlen» (neutral outline).
With mock payments enabled, «Jetzt bezahlen» opens the explicitly labelled test-payment
confirmation; the setup payment screen itself has no test-payment section. When
disabled, it explains that online payment is unavailable and disables the button.
No real transaction occurs. Paid memberships cannot be changed through setup;
outstanding upgrades are handled by the separate dashboard payment screen.

«Später bezahlen» and the successful-payment continuation both open print selection
directly. The print step shows available product images, titles, descriptions and
quantity dropdowns (none or 1–10 bundles), without a summary, separate edit action
or delivery-information section. «Weiter» saves and advances to the business handoff.
Selecting no products creates no empty order; clearing an existing selection removes
only the selected active products. Existing inactive items are preserved and noted.
Invalid quantities remain on the same step with errors and the submitted values.
Expired deadlines and empty catalogues show a short explanation and a continue link;
closed-deadline POSTs cannot modify orders. Pending users may order print materials;
this does not complete participation.

«Geschäftsangaben» only explains that the user can now complete their store information
in the app and links to the business overview. It has no form and creates no business record.
The existing dashboard editor remains the only member business editor and uses
«Änderungen speichern», with no separate «Geschäft anlegen» action. Older accounts
without a business get one on their first editor visit when their saved registration
details are valid; incomplete details remain prefilled for completion and saving.
Creation is serialized on the account, and existing business details are preserved.
Memberships
without a listing skip this handoff and go straight to their dashboard explanation.
Dashboard print editing still returns to its own order summary after saving.

The setup header and bottom action bar stay outside the scrolling main content.
The layout renders the stepper exactly once on every setup page, including payment
success. The test checkout has no stepper, sidebar or app action bars. Dashboard screens
have no stepper. External submit buttons target their
forms with the HTML `form` attribute; print selection uses unsaved-change protection.
Flash notifications are not rendered in any layout; inline validation remains visible.

Login and registration validation uses field-level error messages, error borders,
and `aria-invalid` / `aria-describedby`. Registration maps nested business errors
back to the visible fields. Authentication failures keep the generic credentials
message so the form does not disclose which part of the credentials was wrong.
Account lock, confirmation and admin-access errors remain form-level messages.

During Turbo validation failures, `auth-form` keeps the submitted password only in
browser memory and restores it masked into the same failed form. It does not echo
the password in response HTML or store it in cookies, sessions, local storage or
session storage. Password values are scrubbed before Turbo snapshots, navigation
away and page unload. Without JavaScript, Devise retains its normal behavior of
clearing password fields. The first invalid field receives focus after rendering.

`PROD_SEND` is the only email-mode switch. The exact value `true` enables both
account emails and new-shop admin notifications. The exact value `false` enables
private browser previews for newly registered test accounts without sending mail.
If unset, it defaults to `false`; blank or invalid values disable both modes.
The confirmation panel includes a button to open the private email in a new tab.
Set `PROD_SEND=true` explicitly for real users in the environment of both the
web process and the mail worker, then restart those
processes. Disabled admin notifications are not queued for later delivery;
already queued notifications also check the flag before sending.
`RegistrationMailer.new_registration` is queued only by successful self-registration
with this flag enabled, including an account awaiting confirmation. It is sent to
`info@erster-advent-bern.ch`; subsequent updates and admin-created accounts do not
trigger it. Production needs the existing SMTP configuration and a running Solid
Queue worker (e.g. `SOLID_QUEUE_IN_PUMA=true`). Mail links use the existing mailer
host configuration. Registration notifications and Devise account emails share
an inline-styled, table-based branded layout with action buttons and fallback
links. `AccountMailer` applies that layout to Devise. Development previews at
`/rails/mailers` use synthetic users and invalid sample tokens; viewing them does
not send messages.

## Print products and orders

`PrintProduct` contains title, description, Active Storage image, availability and
position, with no price or checkout fields. Images accept JPEG/PNG/WebP/GIF up to
10 MB. Admins manage products at `/admin/print_products`. Disabling instead of
deleting keeps existing requests intact. When changing a bundle's physical
composition between years, disable the old product and create a new definition
so historical quantities retain their meaning.

`PrintOrder` belongs to User and year (database unique index). `PrintOrderItem`
holds one positive integer bundle quantity per product/order (unique index and
database check). Members select 1–10 bundles in a dropdown; «Keine»
submits zero to omit/remove an item. The member endpoint also enforces the upper
limit. Admin corrections retain a numeric input for larger existing allocations.
Updates are atomic; invalid quantities
do not partially save an order. User parameters are scoped to the current user,
active year and available products. Existing inactive items remain visible and
unchanged; admins can correct them. User/record locks serialize creation and edits.

`/admin/print_orders` filters by year and totals every requested product across
that year's orders, independently of pagination. Detail/edit screens link to the
user and business. Store users see their order and distribution information at
`/app/print_order`. Old `/app/products` and `/app/myorders` links redirect here.
The sidebar contains only «Meine Printbestellung», opening this summary; editing
requires the explicit edit button and stays in the same dashboard layout. The
editor uses equal-height cards with the quantity controls aligned at the bottom.
The summary includes material images (when available), descriptions, per-item
bundle counts, totals and the last update time. Its edit button sits below the
order details instead of in the top bar and remains subject to the deadline.
Both member material screens show the annual distribution date and instructions
as understated text below the materials, without the former blue banner or
«Gratis» labels.

## Admin payment visibility and future integration

### Admin lists

Admin user, business, payment, order and product tables share one compact list
layout. The title/search toolbar and pagination footer stay outside the scrolling
table region. A funnel button opens a keyboard-accessible filter dialog; search,
filters and page size are preserved during pagination. Filter changes start at
page one. Invalid filter values are ignored and pagination is bounded to valid
pages with 10, 20 or 50 rows per page.

Payment filters distinguish fully paid memberships from outstanding upgrade
differences. Print-order totals always cover the whole selected year, even when
the list is filtered. Totals and distribution settings are collapsible above
their respective tables; invalid distribution dates keep the form open.

The admin store detail page has a fixed heading and a structured overview of
business/contact/billing fields, online links, rich descriptions and uploaded
images. The owner links to their user record; approval remains editable without
status banners. Store-scoped print orders show their materials and bundle counts.
Payment history separates the original membership amount from each upgrade's
difference, preserving references, confirmation dates and test-payment markers.
Orders and payments precede the online-presence section. The overview also shows
the current membership/payment status, and saving approval changes requires a
confirmation. The entry link in the fixed header opens the public page when
eligible; otherwise it opens an admin-only, non-indexable preview without
changing the store's public visibility.
The overview labels the store's last update as «Geändert am». Admin and member
editors share the same business fields, section layout, category picker and image
previews, with fixed header/save bars and unsaved-change protection. Admin saves
remain scoped to the selected store; approval is managed in the overview. Validation
errors keep the form marked as unsaved so corrections can be submitted immediately.

User details use the same overview layout, with account/contact data, login
activity, linked business, membership, orders and payments. Passwords, hashes,
OTP values and authentication tokens are never displayed. Existing accounts can
only change role from Admin to Superadmin; the model rejects all other transitions
and the admin endpoint retains its Superadmin authorization requirement.

Clearing a list search automatically submits the current filters without a page
parameter, and duplicate browser clear events do not cause duplicate submissions.
Print-product creation and editing use open form sections without a card, with
fixed navigation/save bars and the same validation/unsaved-change behavior.

### Dummy payment for testing, including production

With `PROD_PAYMENT=false`, choose **Jetzt bezahlen → CHF … testweise bezahlen**
during setup, or **Zur Zahlung → Testzahlung öffnen → CHF … testweise bezahlen**
from the dashboard. Both `/app/setup/test_payment` and `/app/test_payment` use the
standalone `checkout` layout, with a Stripe-like two-column summary and payment
panel that stacks on mobile. It is explicitly labelled as a simulation, not an
actual Stripe integration. Fixed example card fields are disabled and have no
names, so no card data is requested or submitted. The form submits only the signed
quote and normal framework fields. Upgrade summaries show the previous payment
as a credit and only the outstanding difference as due. Cancel links return to
the originating payment screen. Both entry points use the same signed-quote processing,
current-user scoping and payment rules. GET never changes payment
state; the confirmation POST activates the selected membership/upgrade through
the existing payment methods. Successful payments return to
`/app/setup/payment?status=success` for setup or
`/app/participation/payment?status=success` for the dashboard. The signed quote
preserves the originating flow without trusting a redirect URL from the request.
The success screen returns to «Bezahlung» in the setup stepper and offers
«Weiter zur Printbestellung». Dashboard payment success returns to the app layout and offers
«Zur Mitgliedschaft». The success screen requires the current membership to be
paid with no outstanding upgrade; the query parameter never changes payment state
or serves as proof of payment. Refreshing the confirmation is safe.

`EventConfiguration.dummy_payments_enabled?` honors `PROD_PAYMENT=false` in every
environment, including production. `true`, blank or invalid values disable the
mock; when unset, only development/test enable it. Both GET and POST return 404
when disabled, including confirmation with a previously issued token. Set this in
the deployment environment and restart/redeploy the app. `PROD_PAYMENT=true` does
not enable a real provider; manual admin confirmation remains available.
Simulated payments activate real membership records and remain marked as paid
after the flag changes; enabling the mock in production is an explicit opt-in.
Authentication,
normal CSRF protection, current-user/current-year scoping, and an expiring signed
quote protect the action. The quote binds the membership, upgrade ID, amount and
selection version. Changed or expired quotes are rejected. Repeated confirmation
does not pay a later upgrade. Simulated records store `payment_provider: dummy`
and a reference, and their detail views clearly identify them as test payments.
There is no real money transfer or external payment provider.

### Manual confirmation and provider integration

User and Business detail pages share a participation/payment history with year,
category, amount, status and paid date. `/admin/participations` provides an overview.
Outside the enabled dummy payment, only Admin/Superadmin controllers
can invoke payment confirmation. `Participation#mark_unpaid!` remains admin-only.
The UI labels these as manual status changes, not transactions.
Upgrade payments have a separate «Differenzzahlung bestätigen» action keyed by
upgrade ID at `/admin/participation_upgrades/:id`. Admin details show each upgrade's
quoted total, prior payment, difference and confirmation date. The original
membership payment cannot be reset with the general paid/unpaid switch once
upgrade records exist, as that would erase the credit underlying those records.
Refunds, cancellations and reversing confirmed upgrades need a separate audited
workflow and are not implemented here.

Future payment integration points:

1. Add provider session creation from `App::ParticipationsController#payment` and
   its status view, using the persisted participation ID/year/category/amount
   (currency CHF), not request-supplied prices. For an upgrade, bind the checkout
   to its upgrade ID and quoted `difference_cents`, not the full membership total.
2. Populate `payment_provider` and `payment_reference` on that participation.
3. Add a separately authenticated, idempotent provider webhook. Verify signature,
   transaction ownership/reference, currency CHF and exact `amount_cents`, then
   invoke `Participation#mark_paid!` while holding the participation row lock.
   For an upgrade, verify its exact difference and call
   `ParticipationUpgrade#mark_paid!` instead. Do not use initial membership payment
   confirmation to settle an upgrade. A success redirect alone must never mark
   payment complete.
4. Extend explicit states if failed/refunded provider events require them; do not
   route print orders through payment. No provider SDK, external checkout, real
   online payment or automatic renewal is included now. The dummy confirmation
   remains a simulation even when explicitly enabled in production.

## Verification and remaining legacy code

### Admin print exports

The Printbestellungen list shows a Produkt/Anzahl totals table above the orders for the selected
participation year (current year by default), independently of search and content
filters. Quantities are bundles; product titles describe the bundle contents.
The E-Mails navigation item has been removed; its legacy route is unchanged.

The **Drucken** menu offers **Adressen** and **Briefe**. Both include all nonempty
print orders in the selected year, including unpaid memberships and inactive
products, sorted by store name. Exports are admin-only and sent with no-store
cache headers. Nothing is uploaded to an external PDF service or saved on disk.

- Addresses: the menu opens an A4 label settings screen with an actual PDF
  preview. Configure columns (1–6), rows (1–20), each page margin, horizontal
  and vertical gaps, horizontal and vertical text padding (all in mm), and
  font size (8–18 pt). Defaults remain two columns and eight rows, no page
  margins or gaps, and 11 pt type. Label dimensions are calculated from the
  remaining sheet area; addresses fill left to right, then top to bottom.
  Preview outlines are never included in the download. Both preview and
  download use the current settings, which apply only to this print job.
  Invalid values or layouts with insufficient text space are rejected and
  the entered settings are retained for correction. Print at 100% without
  scaling; these are generic dimensions, not a named commercial template.
- Delivery addresses come from the business, with registration contact data as
  fallback; billing addresses are never printed. Missing addresses block the
  label download and link to the records to correct, rather than silently
  omitting an order. Letters remain available with the recorded information.
- Letters: one A4 page per order/store with store/contact details, distribution
  date when set, bundle quantities and an optional shared message (1,000
  characters maximum). The letterhead uses the existing vector logo, restrained
  red accents, numbered order lines and clear typography. The message appears
  above the order table without a heading. Select a store and click **Vorschau aktualisieren** to
  inspect the actual PDF. The initial preview uses the default message; downloads
  always use the current form text. The message is not persisted or put in URLs.
- Download either a combined PDF or a ZIP with one uniquely named PDF per store.
  The same renderer is used for previews and downloads. Content that cannot fit
  legibly on one page, or unsupported font characters, produces an explicit
  validation error instead of clipping content or adding unwanted pages.

PDF generation uses Prawn, prawn-svg and the existing bundled Jakarta font; ZIP downloads
use rubyzip. These are production dependencies. No browser/Python/system PDF
package is needed in production. PDF::Reader is a test-only dependency.

The Minitest suite covers categories, snapshots, annual uniqueness/renewal,
public eligibility and direct access, quantity validation and atomicity, skip/
return flow, authorization, admin payment changes, image uploads, business/account
editing and registration mail. Rails integration tests render the affected views.

Verified locally: `bin/rails test` passes 139 tests / 2153 assertions, including
automatic business creation at registration, direct editor navigation, legacy
account initialization without duplicate businesses or overwritten details,
missing configuration, setup/dashboard separation, validation redirects and
branded account emails, annual distribution dates, deadline boundaries and
enforcement, navigation warnings, quantity dropdown limits, detailed order
summaries, account-settings password verification/reconfirmation, and
in-app payment versus guided-setup navigation, no-listing business access restrictions,
upgrade pricing, repeated confirmations, preserved entitlements and admin-only
differential payment confirmation, simulated payments, production mock opt-in and blocking,
expired/stale quote rejection and safe repeat submissions.
Print export tests cover admin permissions, year isolation, 16/17-label page
boundaries and grid positions, missing addresses, inactive products, shared
message content, CSRF-protected preview/download submissions, ZIP contents and
overflow errors. Sample address sheets and letters (including a maximum-length
message) were rendered with Poppler and visually checked for layout and clipping.
Label settings tests also check custom grid pagination and exact margin/gap
positions, invalid geometry, retained form values, CSRF-protected submissions,
and identical preview/download text positions without printed guide outlines.
`node --test test/javascript/admin_list_controller_test.mjs` passes three tests
for clear-event submissions, duplicate-event prevention and ordinary typing.
Tests default to one worker because macOS Ruby/pg can
crash after forking; set `PARALLEL_WORKERS` to opt into parallel execution on a
compatible host. RuboCop passes the changed handwritten Ruby files (respecting
the generated-schema exclusion); Zeitwerk and `git diff --check` pass.
Repository-wide RuboCop still reports 11
pre-existing offenses in untouched files. Brakeman reports the two existing Admin
role-parameter warnings and one Rails support-lifecycle warning; no new warnings
remain. Browser inspection verified the unauthenticated redirect and rendered
email previews; authenticated setup behavior is covered by integration tests,
not an authenticated browser session.

Legacy Product/Order/Payment models, their tables, old admin products/orders/
transactions/invoice screens, marketplace templates and user package/payment
columns remain. They are not used for participation or print ordering and are not
linked from the new workflow. The Store transactions route is still an old
placeholder. Remove or migrate these only after a separate data/usage audit.
The unrelated insurance test scaffolds/fixtures also remain; the test helper now
loads only fixtures for actual application tables.
