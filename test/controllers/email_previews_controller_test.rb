require "test_helper"

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
    assert_select "a[href='#{email_preview_path}']", count: 1
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

  test "the preview URL cannot be opened from another browser even with its cache key" do
    register_test_account
    key = request.session[:account_email_preview_key]
    other_browser = open_session
    other_browser.get email_preview_path, params: { key: key }
    other_browser.assert_response :not_found
    get email_preview_path
    assert_response :success
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
