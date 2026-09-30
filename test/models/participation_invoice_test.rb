require "test_helper"
require "pdf/reader"

class ParticipationInvoiceTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @year = EventConfiguration.year
    InvoiceSetting.create!(InvoiceSetting::DEFAULTS)
    ActionMailer::Base.deliveries.clear
    businesses(:member).update!(business_name: "Haarglanz", billing_address: "Münstergasse 41\n3011 Bern")
  end

  def user_with_business(email, name)
    user = User.create!(email: email, password: "password123", confirmed_at: Time.current)
    user.create_business!(business_name: name, phone: "031 000 00 00", address: "Gasse 1", billing_address: "Gasse 1\n3011 Bern", map_link: "")
    user
  end

  def start_run(key: SecureRandom.uuid, recipients: ParticipationInvoice.recipients(@year))
    InvoiceRun.start!(year: @year, subject: "Rechnung #{@year}", message: InvoiceRun.default_message(@year), idempotency_key: key,
      recipients_digest: ParticipationInvoice.recipients_digest(recipients), created_by: users(:admin))
  end

  test "recipients are exactly the open amounts of the active year" do
    leist = participation_for(users(:member), category: "leist_member")
    non_leist = participation_for(users(:other), category: "non_leist_member")
    no_listing = participation_for(user_with_business("c@example.com", "Kein Eintrag GmbH"), category: "no_listing")
    participation_for(user_with_business("paid@example.com", "Bezahlt AG"), category: "leist_member", paid: true)
    upgraded = participation_for(user_with_business("upgrade@example.com", "Upgrade AG"), category: "no_listing", paid: true)
    upgrade = upgraded.request_upgrade("leist_member")
    assert upgrade.persisted?
    participation_for(user_with_business("deleted@example.com", "Deaktiviert AG").tap { |user| user.update!(deleted: true) })
    participation_for(user_with_business("old@example.com", "Vorjahr AG"), year: @year - 1)

    recipients = ParticipationInvoice.recipients(@year)
    amounts = recipients.to_h { |recipient| [ recipient.participation.id, recipient.amount_cents ] }
    assert_equal({ leist.id => 20_000, non_leist.id => 25_000, no_listing.id => 10_000, upgraded.id => 10_000 }, amounts)
    upgrade_recipient = recipients.find { |recipient| recipient.upgrade }
    assert_equal [ "leist_member", "no_listing" ], [ upgrade_recipient.category, upgrade_recipient.previous_category ]
  end

  test "invoice texts use category letters and differences" do
    run = InvoiceRun.new(year: 2026, creditor: InvoiceSetting.current.snapshot)
    invoice = ParticipationInvoice.new(invoice_run: run, year: 2026, category: "non_leist_member", amount_cents: 25_000)
    assert_equal "Rechnung Erster Advent 2026, Kategorie B: CHF 250.00 (Nicht-Leistmitglied)", invoice.payment_message
    assert_equal "Teilnahmebeitrag\n2026 / Kat. B", invoice.position_title
    upgrade = ParticipationInvoice.new(invoice_run: run, year: 2026, category: "leist_member", previous_category: "no_listing", amount_cents: 10_000)
    assert_equal "Rechnung Erster Advent 2026, Differenz Kategorie C zu A: CHF 100.00 (Leistmitglied)", upgrade.payment_message
  end

  test "a run emails one invoice with the PDF to each recipient" do
    participation_for(users(:member), category: "non_leist_member")
    participation_for(users(:other), category: "no_listing")

    run = nil
    perform_enqueued_jobs { run = start_run }

    assert_equal 2, run.invoices.count
    assert run.invoices.reload.all?(&:sent?)
    assert_equal 2, ActionMailer::Base.deliveries.size
    mail = ActionMailer::Base.deliveries.find { |message| message.to == [ "member@example.com" ] }
    assert_equal "Rechnung #{@year}", mail.subject
    assert_nil mail.html_part
    assert_equal <<~TEXT, mail.text_part.body.decoded.gsub("\r\n", "\n")
      #{InvoiceRun.default_message(@year)}

      Im Anhang finden Sie die Rechnung über CHF 250.00 mit QR-Einzahlungsschein.

      Freundliche Grüsse
      Der Vorstand des Vereins «Erster Advent Untere Altstadt Bern»
    TEXT
    attachment = mail.attachments.first
    assert_equal "application/pdf", attachment.mime_type
    assert_equal "Rechnung-Erster-Advent-#{@year}-haarglanz.pdf", attachment.filename

    reader = PDF::Reader.new(StringIO.new(attachment.decoded))
    assert_equal 2, reader.page_count
    page_one = reader.pages.first.text
    [ "HAARGLANZ", "Münstergasse 41", "Rechnung Teilnahmebeitrag #{@year}", "#{@year} / Kat. B", "250.00", "Berner Kantonalbank – CH96 0079 0016 6004 9421 8" ].each do |text|
      assert_includes page_one, text
    end
    page_two = reader.pages.last.text
    assert_includes page_two, "CHF 250.00 (Nicht-Leistmitglied)"
    assert_includes page_two, "Zahlteil"
  end

  test "the same form submission starts only one run" do
    participation_for(users(:member))
    key = SecureRandom.uuid
    first = start_run(key: key)
    assert_no_difference -> { InvoiceRun.count } do
      assert_equal first, start_run(key: key)
    end
    assert_equal 1, enqueued_jobs.size
  end

  test "a run is refused when the reviewed list is outdated, delivery is off, or data is missing" do
    participation_for(users(:member))
    stale = ParticipationInvoice.recipients(@year)
    participation_for(users(:other))
    error = assert_raises(InvoiceRun::Refused) { start_run(recipients: stale) }
    assert_match "geändert", error.message

    with_env("PROD_SEND" => "false") do
      assert_raises(InvoiceRun::Refused) { start_run }
    end

    businesses(:other).update_columns(billing_address: "", address: "")
    users(:other).update_columns(address: nil)
    assert_raises(InvoiceRun::Refused) { start_run }
    assert_equal 0, InvoiceRun.count
    assert_no_enqueued_jobs
  end

  test "no run without saved bank details" do
    InvoiceSetting.delete_all
    participation_for(users(:member))
    assert_raises(InvoiceRun::Refused) { start_run }
  end

  test "a participation paid after the run started is not billed" do
    participation = participation_for(users(:member))
    run = start_run
    participation.mark_paid!
    perform_enqueued_jobs
    assert run.invoices.first.reload.cancelled?
    assert_empty ActionMailer::Base.deliveries
  end

  test "a changed category after the run started is not billed" do
    participation = participation_for(users(:member), category: "leist_member")
    run = start_run
    participation.update!(category: "non_leist_member")
    perform_enqueued_jobs
    assert run.invoices.first.reload.cancelled?
    assert_empty ActionMailer::Base.deliveries
  end

  test "delivery re-checks PROD_SEND and records the failure" do
    participation_for(users(:member))
    run = start_run
    with_env("PROD_SEND" => "false") { perform_enqueued_jobs }
    invoice = run.invoices.first.reload
    assert invoice.failed?
    assert_match "PROD_SEND", invoice.error_message
    assert_empty ActionMailer::Base.deliveries
  end

  test "SMTP failures are recorded and only failed invoices are sent again" do
    participation_for(users(:member))
    participation_for(users(:other))
    run = start_run
    failing_address = "other@example.com"
    original = ParticipationInvoiceMailer.method(:invoice)
    ParticipationInvoiceMailer.define_singleton_method(:invoice) do |invoice, pdf|
      raise Net::SMTPFatalError.new("550 mailbox unavailable") if invoice.recipient_email == failing_address
      original.call(invoice, pdf)
    end
    begin
      perform_enqueued_jobs
    ensure
      ParticipationInvoiceMailer.singleton_class.remove_method(:invoice)
    end
    assert_equal %w[failed sent], run.invoices.reload.map(&:status).sort
    assert_equal 1, ActionMailer::Base.deliveries.size

    perform_enqueued_jobs { assert_equal 1, run.resend_failed! }
    assert run.invoices.reload.all?(&:sent?)
    assert_equal 2, ActionMailer::Base.deliveries.size
    assert_equal [ "member@example.com", "other@example.com" ], ActionMailer::Base.deliveries.flat_map(&:to).sort
  end

  test "a job never sends an invoice twice" do
    participation_for(users(:member))
    run = start_run
    invoice = run.invoices.first
    perform_enqueued_jobs
    ParticipationInvoiceDeliveryJob.perform_now(invoice.id)
    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_not invoice.reload.requeue!
  end

  test "a text that does not fit the page is refused before anything is stored" do
    participation_for(users(:member))
    long_text = ("Zeile\n" * 30).strip
    error = assert_raises(InvoiceRun::Refused) do
      InvoiceRun.start!(year: @year, subject: "Rechnung", message: long_text, idempotency_key: SecureRandom.uuid,
        recipients_digest: ParticipationInvoice.recipients_digest(ParticipationInvoice.recipients(@year)), created_by: users(:admin))
    end
    assert_match "zu lang", error.message
    assert_equal 0, InvoiceRun.count
  end

  private

  def with_env(values)
    previous = values.to_h { |key, _| [ key, ENV[key] ] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| ENV[key] = value }
  end
end
