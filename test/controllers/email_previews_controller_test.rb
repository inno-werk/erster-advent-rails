require "test_helper"
require "minitest/mock"

class EmailPreviewsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  setup do
    @original_prod_send = ENV["PROD_SEND"]
    @original_cache = Rails.cache
    ENV["PROD_SEND"] = "false"
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    ENV["PROD_SEND"] = @original_prod_send
    Rails.cache = @original_cache
  end

  test "new registration exposes a private preview with a working confirmation link and no delivery" do
    assert_no_emails do
      assert_no_enqueued_emails { register_test_account }
    end
    assert_redirected_to confirmation_pending_path
    follow_redirect!
    assert_select "[data-email-preview-notice-target=prompt]:not([hidden]) a[href='#{email_preview_path}']", count: 1
    assert_select "[data-confirmation-panel] a[href='#{email_preview_path}'][target='_blank'][rel='noopener noreferrer']", text: "E-Mail-Vorschau öffnen"
    assert_select "h1", text: "E-Mail-Adresse bestätigen"
    assert_includes response.body, "Ihre Bestätigungs-E-Mail ist bereit."
    assert_not_includes response.body, "Wir haben Ihnen soeben"
    assert_no_match /confirmation_token=/, response.body

    get email_preview_path
    assert_response :success
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_equal "no-referrer", response.headers["Referrer-Policy"]
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
    assert_select "iframe[sandbox='allow-popups allow-popups-to-escape-sandbox']"
    assert_select "dd", text: "preview@example.com"
    link = preview_document.at_css("a[href*='confirmation_token=']")
    assert_equal "www.example.com", URI.parse(link["href"]).host
    assert_equal "_blank", link["target"]
    fallback_link = preview_document.css("a").find { |anchor| anchor.text.start_with?("http") }
    assert_equal fallback_link["href"], fallback_link.text
    assert_equal "www.example.com", URI.parse(fallback_link.text).host
    get link["href"]
    assert_redirected_to app_setup_participation_path
    assert User.find_by!(email: "preview@example.com").confirmed?
  end

  test "registration and preview retrieval work with the production Solid Cache backend" do
    Rails.cache = ActiveSupport::Cache.lookup_store(:solid_cache_store, expiry_method: :job)
    assert_no_emails { register_test_account }
    assert_redirected_to confirmation_pending_path
    key = request.session[:account_email_preview_key]
    assert AccountEmailPreview.read(key)

    # A new store instance must read the shared database, not process-local memory.
    Rails.cache = ActiveSupport::Cache.lookup_store(:solid_cache_store, expiry_method: :job)
    follow_redirect!
    assert_select "[data-confirmation-panel] a[href='#{email_preview_path}']"
    get email_preview_path
    assert_response :success
    link = preview_document.at_css("a[href*='confirmation_token=']")
    get link["href"]
    assert_redirected_to app_setup_participation_path
    assert User.find_by!(email: "preview@example.com").confirmed?
  end

  test "missing cache index does not turn successful registration into a 500 and resend can recover" do
    failure = ->(*) { raise ArgumentError, "No unique index found for key_hash" }
    Rails.cache.stub(:write, failure) do
      assert_difference "User.count", 1 do
        assert_no_emails { register_test_account }
      end
    end
    assert_redirected_to confirmation_pending_path
    assert_nil request.session[:account_email_preview_key]
    follow_redirect!
    assert_select "[role='status']", text: /Ihre Registrierung wurde gespeichert/
    assert_select "a[href='#{email_preview_path}']", count: 0

    post user_confirmation_path, params: { user: { email: "preview@example.com" } }
    get email_preview_path
    assert_response :success
    assert preview_document.at_css("a[href*='confirmation_token=']")
  end

  test "cache read and delete failures remain private and do not crash the response" do
    register_test_account
    failure = ->(*) { raise ActiveRecord::StatementInvalid, "missing cache table" }
    Rails.cache.stub(:read, failure) do
      get confirmation_pending_path
      assert_response :success
      assert_select "a[href='#{email_preview_path}']", count: 0
      get email_preview_path
      assert_response :not_found
    end
    Rails.cache.stub(:delete, failure) do
      delete destroy_user_session_path
      assert_response :redirect
    end
    get email_preview_path
    assert_response :not_found
  end

  test "a cache write returning false does not publish a broken preview key" do
    Rails.cache.stub(:write, false) { register_test_account }
    assert_redirected_to confirmation_pending_path
    assert_nil request.session[:account_email_preview_key]
    get email_preview_path
    assert_response :not_found
  end

  test "the preview URL cannot be opened from another browser even with its cache key" do
    register_test_account
    key = request.session[:account_email_preview_key]
    other_browser = open_session
    other_browser.get email_preview_path, params: { key: key }
    other_browser.assert_response :not_found
    get email_preview_path
    assert_response :success
  end

  test "opening a preview dismisses its notice without revoking the preview or confirming the account" do
    register_test_account
    follow_redirect!
    notice_id = css_select("[data-email-preview-notice]").sole["data-email-preview-notice-id-value"]
    assert notice_id.present?
    get email_preview_path
    assert_response :success
    assert_select "body[data-email-preview-notice-id=?]", notice_id
    assert_select "script[type=module][src*='email_preview_opened']"
    assert_not User.find_by!(email: "preview@example.com").confirmed?

    get confirmation_pending_path
    assert_select "[data-email-preview-notice]", count: 0
    assert_select "[data-email-preview-notice-target=prompt][hidden]"
    assert_select "[data-email-preview-notice-target=opened]:not([hidden])", text: /Die E-Mail-Vorschau wurde geöffnet/
    get email_preview_path
    assert_response :success
    link = preview_document.at_css("a[href*='confirmation_token=']")
    get link["href"]
    follow_redirect!
    assert_select "[data-email-preview-notice]", count: 0
  end

  test "a new email brings its preview notice back with a different identifier" do
    register_test_account
    get email_preview_path
    previous_id = css_select("body").sole["data-email-preview-notice-id"]
    post user_confirmation_path, params: { user: { email: "preview@example.com" } }
    follow_redirect!
    assert_select "[data-email-preview-notice]" do |notices|
      assert_not_equal previous_id, notices.sole["data-email-preview-notice-id-value"]
    end
    assert_select "[data-email-preview-notice-target=prompt]:not([hidden])"
  end

  test "an unsuccessful preview request does not dismiss the notice" do
    register_test_account
    Rails.cache.stub(:read, nil) do
      get email_preview_path
      assert_response :not_found
    end
    get confirmation_pending_path
    assert_select "[data-email-preview-notice]"
    assert_select "[data-email-preview-notice-target=prompt]:not([hidden])"
  end

  test "resend replaces the owning browser preview without sending mail" do
    register_test_account
    old_key = request.session[:account_email_preview_key]
    assert_no_emails { post user_confirmation_path, params: { user: { email: "preview@example.com" } } }
    assert_nil AccountEmailPreview.read(old_key)
    get email_preview_path
    assert_response :success
    assert preview_document.at_css("a[href*='confirmation_token=']")
  end

  test "password reset can be previewed for the newly registered test account only" do
    register_test_account
    assert_no_emails { post user_password_path, params: { user: { email: "preview@example.com" } } }
    get email_preview_path
    assert_response :success
    assert preview_document.at_css("a[href*='reset_password_token=']")

    post user_password_path, params: { user: { email: users(:admin).email } }
    get email_preview_path
    assert_select "dd", text: "preview@example.com"
    assert_select "dd", text: users(:admin).email, count: 0
  end

  test "existing user and admin recovery requests never expose their messages" do
    [ users(:member), users(:admin) ].each do |user|
      assert_no_emails { post user_password_path, params: { user: { email: user.email } } }
      get email_preview_path
      assert_response :not_found
      user.update_columns(confirmed_at: nil)
      assert_no_emails { post user_confirmation_path, params: { user: { email: user.email } } }
      get email_preview_path
      assert_response :not_found
    end
  end

  test "duplicate registration does not grant access to an existing account" do
    register_test_account(email: users(:member).email)
    assert_response :unprocessable_entity
    get email_preview_path
    assert_response :not_found
  end

  test "previews expire after thirty minutes and cache contents are encrypted" do
    register_test_account
    key = request.session[:account_email_preview_key]
    encrypted = Rails.cache.read("account-email-preview:#{key}")
    assert_not_includes encrypted, "preview@example.com"
    assert_not_includes encrypted, "confirmation_token"
    travel 31.minutes do
      assert_nil AccountEmailPreview.read(key)
      get email_preview_path
      assert_response :not_found
    end
  end

  test "logout and enabling real delivery revoke the preview" do
    register_test_account
    ENV["PROD_SEND"] = "true"
    get email_preview_path
    assert_response :not_found
    ENV["PROD_SEND"] = "false"
    user = User.find_by!(email: "preview@example.com")
    user.confirm
    sign_in user
    delete destroy_user_session_path
    get email_preview_path
    assert_response :not_found
  end

  test "signing into another account cannot expose the previous test account preview" do
    register_test_account
    sign_in users(:member)
    get email_preview_path
    assert_response :not_found
  end

  test "preview rendering escapes user content and tampered cache entries are rejected" do
    register_test_account(name: "<script>alert('unsafe')</script>")
    key = request.session[:account_email_preview_key]
    get email_preview_path
    assert_empty preview_document.css("script")
    assert_includes preview_document.text, "<script>alert('unsafe')</script>"
    Rails.cache.write("account-email-preview:#{key}", "tampered")
    get email_preview_path
    assert_response :not_found
  end

  test "one flag enables account and admin delivery without exposing previews" do
    ENV["PROD_SEND"] = "true"
    assert_emails 2 do
      perform_enqueued_jobs { register_test_account }
    end
    get email_preview_path
    assert_response :not_found
  end

  test "unset PROD_SEND defaults to a private preview inside the confirmation panel" do
    ENV.delete("PROD_SEND")
    assert_no_emails do
      assert_no_enqueued_emails { register_test_account }
    end
    follow_redirect!
    assert_select "[data-confirmation-panel] a[href='#{email_preview_path}'][target='_blank']", text: "E-Mail-Vorschau öffnen"
    assert_not_includes response.body, "Der E-Mail-Versand ist derzeit deaktiviert"
    get email_preview_path
    assert_response :success
    assert preview_document.at_css("a[href*='confirmation_token=']")
    other_browser = open_session
    other_browser.get email_preview_path
    other_browser.assert_response :not_found
  end

  test "invalid configuration disables delivery without exposing previews" do
    [ "", "1", "invalid" ].each_with_index do |value, index|
      ENV["PROD_SEND"] = value
      assert_no_emails do
        assert_no_enqueued_emails { register_test_account(email: "disabled-#{index}@example.com") }
        AccountMailer.reset_password_instructions(users(:member), "test-token").deliver_now
        RegistrationMailer.new_registration(users(:member)).deliver_now
      end
      get email_preview_path
      assert_response :not_found
    end
  end

  test "direct and queued mailer delivery cannot bypass preview mode" do
    assert_no_emails do
      AccountMailer.reset_password_instructions(users(:member), "test-token").deliver_now
      RegistrationMailer.new_registration(users(:member)).deliver_now
      perform_enqueued_jobs do
        AccountMailer.confirmation_instructions(users(:member), "test-token").deliver_later
      end
    end
  end

  private

  def register_test_account(email: "preview@example.com", name: "Testperson")
    post user_registration_path, params: { user: {
      business_name: "Vorschau Geschäft", email: email, name: name,
      address: "Bern", phone: "031 000 00 00", password: "password123"
    } }
  end

  def preview_document
    Nokogiri::HTML(Nokogiri::HTML(response.body).at_css("iframe")["srcdoc"])
  end
end
