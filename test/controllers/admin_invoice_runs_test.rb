require "test_helper"
require "pdf/reader"

class AdminInvoiceRunsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @year = EventConfiguration.year
    InvoiceSetting.create!(InvoiceSetting::DEFAULTS)
    @participation = participation_for(users(:member), category: "non_leist_member")
    ActionMailer::Base.deliveries.clear
    sign_in users(:admin)
  end

  def send_params(**overrides)
    get new_admin_invoice_run_path
    form = css_select("#invoice-run-form").first
    fields = %w[subject message idempotency_key recipients_digest].to_h { |name| [ name.to_sym, form.at_css("[name=#{name}]")["value"] ] }
    fields.merge(confirmed: "1").merge(overrides)
  end

  test "payments list links to the invoice page and the menu shows bank details" do
    get admin_participations_path(year: @year, payment_status: "pending")
    assert_response :success
    assert_select ".admin-list-titlebar a[href=?]", new_admin_invoice_run_path, text: /Rechnungen versenden/
    assert_select "aside a[href=?]", admin_invoice_setting_path, text: /Bankverbindung/
  end

  test "invoice page lists open amounts with total" do
    get new_admin_invoice_run_path
    assert_response :success
    assert_select "[data-testid=invoice-recipients] tbody tr", count: 1
    assert_select "[data-testid=invoice-recipients] tbody", text: /CHF 250\.00/
    assert_select "[data-testid=invoice-summary]", text: /1 Geschäft.*CHF 250\.00/m
    assert_select "iframe[name=invoice-preview][src=?]", preview_admin_invoice_runs_path
    assert_select "details.admin-step[open]", count: 4
    assert_select "#step-1 summary", text: /Übersicht/
    assert_select "#step-4 #invoice-run-form button[type=submit]:not([disabled])", text: /Rechnungen an 1 Geschäft senden/
    assert_select "#participation_id[form=invoice-run-form]"
    assert_select "#invoice-run-form input[type=hidden][name=subject][value=?]", InvoiceRun.default_subject(@year)
    assert_select "[data-testid=invoice-subject]", text: InvoiceRun.default_subject(@year)
    assert_select "[data-testid=invoice-message]", text: /Ersten Advent #{@year}/
    assert_select "#invoice-text textarea", count: 0
    assert_select "#invoice-text a[href=?]", new_admin_invoice_run_path(edit_text: 1, anchor: "invoice-text"), text: /Bearbeiten/
    assert_select "[data-testid=invoice-checks] li", count: 6
    assert_includes response.headers["Cache-Control"], "no-store"
  end

  test "preview renders the PDF of a listed participation only" do
    post preview_admin_invoice_runs_path, params: { participation_id: @participation.id, message: "Vorschautext" }
    assert_response :success
    assert_equal "application/pdf", response.media_type

    paid = participation_for(users(:other), paid: true)
    post preview_admin_invoice_runs_path, params: { participation_id: paid.id }
    assert_response :unprocessable_entity
    assert_includes response.body, "Keine offene Zahlung"
  end

  test "the form token is accepted by preview and send with CSRF protection enabled" do
    ActionController::Base.allow_forgery_protection = true
    get new_admin_invoice_run_path
    form = css_select("#invoice-run-form").first
    token = form.at_css("[name=authenticity_token]")["value"]
    fields = %w[subject message idempotency_key recipients_digest].to_h { |name| [ name, form.at_css("[name=#{name}]")["value"] ] }

    post preview_admin_invoice_runs_path, params: { authenticity_token: token, participation_id: @participation.id, message: "Neu" }
    assert_response :success
    assert_equal "application/pdf", response.media_type

    post admin_invoice_runs_path, params: fields.merge(authenticity_token: token, confirmed: "1")
    assert_redirected_to admin_invoice_run_path(id: InvoiceRun.sole.id)

    post preview_admin_invoice_runs_path, params: { participation_id: @participation.id }
    assert_response :unprocessable_entity
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  test "sending emails the saved text to every open amount once and shows the run" do
    patch text_admin_invoice_runs_path, params: { invoice_text: { subject: "Ihre Rechnung", message: "Bitte bezahlen & danke." } }
    params = send_params
    perform_enqueued_jobs do
      post admin_invoice_runs_path, params: params
      post admin_invoice_runs_path, params: params
    end
    run = InvoiceRun.sole
    assert_redirected_to admin_invoice_run_path(id: run.id)
    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_equal "Ihre Rechnung", ActionMailer::Base.deliveries.first.subject
    assert_includes ActionMailer::Base.deliveries.first.text_part.body.decoded, "Bitte bezahlen & danke."
    assert_equal [ "Ihre Rechnung", "Bitte bezahlen & danke." ], [ run.subject, run.message ]
    assert_equal users(:admin), run.created_by

    get admin_invoice_run_path(id: run.id)
    assert_response :success
    assert_select "[data-testid=invoice-run-counts]", text: /Versendet\s*1/
  end

  test "subject and text are saved per year and shown read-only" do
    get new_admin_invoice_run_path(edit_text: 1)
    assert_select "#invoice-text form[action=?] textarea[name=?]", text_admin_invoice_runs_path, "invoice_text[message]"
    assert_select "#step-4 #invoice-run-form button[type=submit][disabled]"
    assert_select "[data-testid=invoice-checks]", text: /Bitte zuerst in Schritt 2 speichern/

    patch text_admin_invoice_runs_path, params: { invoice_text: { subject: " Neuer  Betreff ", message: "Zeile 1\r\nZeile 2" } }
    assert_redirected_to new_admin_invoice_run_path(anchor: "step-2")
    text = InvoiceText.sole
    assert_equal [ @year, "Neuer Betreff", "Zeile 1\nZeile 2", users(:admin) ], [ text.year, text.subject, text.message, text.updated_by ]

    get new_admin_invoice_run_path
    assert_select "[data-testid=invoice-subject]", text: "Neuer Betreff"
    assert_select "#invoice-text textarea", count: 0
    assert_equal "Neuer Betreff", InvoiceText.for_year(@year).subject
    assert_equal InvoiceRun.default_subject(@year + 1), InvoiceText.for_year(@year + 1).subject
  end

  test "empty lines of the text are kept in the view, the email and the PDF" do
    patch text_admin_invoice_runs_path, params: { invoice_text: { subject: "Rechnung", message: "Guten Tag\r\n\r\nBitte bezahlen." } }
    assert_equal "Guten Tag\n\nBitte bezahlen.", InvoiceText.sole.message

    params = send_params
    assert_equal "Guten Tag\n\nBitte bezahlen.", css_select("[data-testid=invoice-message].whitespace-pre-line").sole.text
    perform_enqueued_jobs { post admin_invoice_runs_path, params: params }

    mail = ActionMailer::Base.deliveries.sole
    assert mail.text_part.body.decoded.gsub("\r\n", "\n").start_with?("Guten Tag\n\nBitte bezahlen.\n\nIm Anhang")
    lines = PDF::Reader.new(StringIO.new(mail.attachments.first.decoded)).pages.first.text.lines.map(&:strip)
    greeting = lines.index("Guten Tag")
    assert_equal [ "Guten Tag", "", "Bitte bezahlen." ], lines[greeting, 3]
  end

  test "invalid text is not saved and stays in edit mode" do
    patch text_admin_invoice_runs_path, params: { invoice_text: { subject: "", message: "Rechnung 🎄" } }
    assert_response :unprocessable_entity
    assert_equal 0, InvoiceText.count
    assert_select "#invoice-text textarea[name=?]", "invoice_text[message]", text: "Rechnung 🎄"
    assert_select "#invoice-text [role=alert]", text: /Betreff/
    assert_select "#invoice-text [role=alert]", text: /nicht/

    patch text_admin_invoice_runs_path, params: { invoice_text: { subject: "Rechnung", message: ("Zeile\n" * 30).strip } }
    assert_response :unprocessable_entity
    assert_select "#invoice-text [role=alert]", text: /zu lang/
    assert_equal 0, InvoiceText.count
  end

  test "sending is refused when the text changed after the page was shown" do
    params = send_params
    InvoiceText.create!(year: @year, subject: "Geändert", message: "Anderer Text")
    post admin_invoice_runs_path, params: params
    assert_response :unprocessable_entity
    assert_equal 0, InvoiceRun.count
    assert_includes response.body, "inzwischen geändert"
  end

  test "sending requires the confirmation checkbox" do
    post admin_invoice_runs_path, params: send_params(confirmed: nil)
    assert_response :unprocessable_entity
    assert_equal 0, InvoiceRun.count
    assert_includes response.body, "Bitte bestätigen"
  end

  test "a changed list is refused and shown again" do
    params = send_params
    participation_for(users(:other))
    post admin_invoice_runs_path, params: params
    assert_response :unprocessable_entity
    assert_equal 0, InvoiceRun.count
    assert_select "[data-testid=invoice-recipients] tbody tr", count: 2
  end

  test "bank details are shown read-only and edited on a separate form" do
    get admin_invoice_setting_path
    assert_response :success
    assert_select "main form input, main form textarea", count: 0
    assert_select "[data-testid=setting-details]", text: /CH96 0079 0016 6004 9421 8/
    assert_select "[data-testid=setting-details]", text: /Berner Kantonalbank/
    assert_select "[data-testid=setting-letterhead] span", count: 7
    assert_select "[data-testid=setting-status]", text: /Gespeichert/
    assert_select "a[href=?]", edit_admin_invoice_setting_path, text: /Bearbeiten/

    get edit_admin_invoice_setting_path
    assert_select "form[action=?] input[name=?]", admin_invoice_setting_path, "invoice_setting[iban]"
    assert_select "a[href=?]", admin_invoice_setting_path, text: "Abbrechen"

    patch admin_invoice_setting_path, params: { invoice_setting: { iban: "CH96 0079 0016 6004 9421 9" } }
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /IBAN hat eine ungültige Prüfziffer/

    InvoiceSetting.delete_all
    get admin_invoice_setting_path
    assert_select "[data-testid=setting-status]", text: /Noch nicht gespeichert/
    assert_select "a[href=?]", edit_admin_invoice_setting_path, text: /Prüfen und speichern/
  end

  test "bank details are updated from the menu and from the invoice page" do
    patch admin_invoice_setting_path, params: { invoice_setting: { iban: "CH93 0076 2011 6238 5295 7", bank_name: "Neue Bank" } }
    assert_redirected_to admin_invoice_setting_path
    assert_equal "CH9300762011623852957", InvoiceSetting.current.iban

    patch admin_invoice_setting_path, params: { return_to: "invoice_run", invoice_setting: { bank_name: "Andere Bank" } }
    assert_redirected_to new_admin_invoice_run_path

    patch admin_invoice_setting_path, params: { return_to: "https://evil.example", invoice_setting: { iban: "CH00 0000" } }
    assert_response :unprocessable_entity
    assert_equal "Andere Bank", InvoiceSetting.current.reload.bank_name
  end

  test "members and visitors cannot reach any invoice endpoint" do
    run = InvoiceRun.create!(year: @year, subject: "x", message: "y", creditor: InvoiceSetting.current.snapshot, idempotency_key: "k")
    [ users(:member), nil ].each do |user|
      sign_out :user
      sign_in user if user
      expected = user ? root_path : admin_login_path
      [ new_admin_invoice_run_path, admin_invoice_run_path(id: run.id), preview_admin_invoice_runs_path, admin_invoice_setting_path, edit_admin_invoice_setting_path ].each do |path|
        get path
        assert_redirected_to expected
      end
      post admin_invoice_runs_path, params: { confirmed: "1", subject: "x", message: "y", idempotency_key: "new" }
      assert_redirected_to expected
      post resend_admin_invoice_run_path(id: run.id)
      assert_redirected_to expected
      patch admin_invoice_setting_path, params: { invoice_setting: { bank_name: "Hacked" } }
      assert_redirected_to expected
      patch text_admin_invoice_runs_path, params: { invoice_text: { subject: "Hacked", message: "Hacked" } }
      assert_redirected_to expected
    end
    assert_equal 1, InvoiceRun.count
    assert_no_enqueued_jobs
    assert_not_equal "Hacked", InvoiceSetting.current.bank_name
    assert_equal 0, InvoiceText.count
  end
end
