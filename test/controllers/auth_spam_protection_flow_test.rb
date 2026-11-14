require "test_helper"
require "minitest/mock"

class AuthSpamProtectionFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  REGISTRATION = {
    business_name: "Spam GmbH", email: "spam-check@example.com",
    registration_street_address: "Kramgasse 3", registration_postal_city: "3011 Bern",
    name: "Neue Person", phone: "+41310000000", password: "password123"
  }.freeze

  setup do
    @original_env = ENV.to_h.slice("TURNSTILE_SITE_KEY", "TURNSTILE_SECRET_KEY")
    ENV.delete("TURNSTILE_SITE_KEY")
    ENV.delete("TURNSTILE_SECRET_KEY")
    @rate_limit_backend = ActiveSupport::Cache::MemoryStore.new
    AuthSpamProtection.rate_limit_store.backend = @rate_limit_backend

    @unconfirmed = User.new(email: "unconfirmed@example.com", password: "password123")
    @unconfirmed.skip_confirmation_notification!
    @unconfirmed.save!
    @locked = users(:other)
    @locked.lock_access!(send_instructions: false)
    ActionMailer::Base.deliveries.clear
    clear_enqueued_jobs
  end

  teardown do
    AuthSpamProtection.rate_limit_store.backend = nil
    %w[TURNSTILE_SITE_KEY TURNSTILE_SECRET_KEY].each { |key| ENV[key] = @original_env[key] }
  end

  test "every protected form renders a hidden, untabbable honeypot and a signed render timestamp" do
    [ new_user_registration_path, new_user_password_path, new_user_confirmation_path, new_user_unlock_path ].each do |path|
      get path
      assert_response :success
      assert_select "form [aria-hidden=true] input[name=form_note][tabindex='-1'][autocomplete=off][value='']", 1, path
      token = css_select("input[type=hidden][name=form_rendered_at]").first&.[]("value")
      assert AuthSpamProtection.rendered_at(token), "missing valid timestamp on #{path}"
    end
  end

  test "honeypot submissions get the success response without records, tokens, or mail" do
    assert_no_difference [ "User.count", "Business.count" ] do
      assert_nothing_sent do
        post user_registration_path, params: { **auth_form_fields, form_note: "https://spam.example", user: REGISTRATION }
      end
    end
    assert_response :see_other
    assert_redirected_to confirmation_pending_path

    assert_nothing_sent do
      post user_password_path, params: { **auth_form_fields, form_note: "x", user: { email: users(:member).email } }
    end
    assert_response :see_other
    assert_redirected_to new_user_session_path
    assert_nil users(:member).reload.reset_password_token

    confirmation_token = @unconfirmed.confirmation_token
    assert_nothing_sent do
      post user_confirmation_path, params: { **auth_form_fields, form_note: "x", user: { email: @unconfirmed.email } }
    end
    assert_response :see_other
    assert_redirected_to confirmation_pending_path
    assert_equal confirmation_token, @unconfirmed.reload.confirmation_token

    assert_nil @locked.unlock_token
    assert_nothing_sent do
      post user_unlock_path, params: { **auth_form_fields, form_note: "x", user: { email: @locked.email } }
    end
    assert_response :see_other
    assert_redirected_to new_user_session_path
    assert_nil @locked.reload.unlock_token
  end

  test "honeypot responses match the real success response" do
    { user_password_path => users(:member).email,
      user_confirmation_path => @unconfirmed.email,
      user_unlock_path => @locked.email }.each do |path, email|
      post path, params: { **auth_form_fields, user: { email: email } }
      real = [ response.status, response.location, flash[:notice] ]
      assert_not ActionMailer::Base.deliveries.empty?, "real request to #{path} sent no mail"

      post path, params: { **auth_form_fields, form_note: "x", user: { email: email } }
      assert_equal real, [ response.status, response.location, flash[:notice] ], path
    end
  end

  test "submissions that are too fast, unsigned, tampered, foreign, or expired are re-rendered without side effects" do
    foreign = AuthSpamProtection.verifier.generate(1.minute.ago.to_f, purpose: :other)
    invalid_timestamps = {
      "too fast" => AuthSpamProtection.form_token(1.second.ago),
      "missing" => nil,
      "tampered" => "#{AuthSpamProtection.form_token(1.minute.ago)}x",
      "foreign purpose" => foreign,
      "expired" => AuthSpamProtection.form_token(25.hours.ago)
    }

    invalid_timestamps.each do |label, token|
      fields = { form_note: "", form_rendered_at: token }.compact

      assert_no_difference [ "User.count", "Business.count" ] do
        assert_nothing_sent { post user_registration_path, params: { **fields, user: REGISTRATION } }
      end
      assert_response :unprocessable_entity, label
      assert_select "[role=alert]", text: AuthSpamProtection::RETRY_MESSAGE
      assert_select "input[name='user[business_name]'][value='Spam GmbH']"
      assert_select "input[name='user[email]'][value='spam-check@example.com']"
      assert_select "input[name='user[password]'][value]", 0
      assert_select "#user_password_hint"
      assert_select "p", text: "Bitte prüfen Sie die markierten Felder.", count: 0
      assert AuthSpamProtection.rendered_at(css_select("input[name=form_rendered_at]").first["value"]), "re-render needs a fresh token"

      { user_password_path => users(:member).email,
        user_confirmation_path => @unconfirmed.email,
        user_unlock_path => @locked.email }.each do |path, email|
        assert_nothing_sent { post path, params: { **fields, user: { email: email } } }
        assert_response :unprocessable_entity, "#{label} #{path}"
        assert_select "[role=alert]", text: /#{Regexp.escape(AuthSpamProtection::RETRY_MESSAGE)}/
        assert_select "input[name='user[email]'][value=?]", email
      end
    end

    assert_nil users(:member).reload.reset_password_token
  end

  test "malformed resource params do not raise" do
    post user_password_path, params: { form_note: "", user: "not-a-hash" }
    assert_response :unprocessable_entity
    post user_registration_path, params: { form_note: "" }
    assert_response :unprocessable_entity
  end

  test "registration is limited to 10 attempts per hour per IP" do
    10.times do
      post user_registration_path, params: { **auth_form_fields, form_note: "x", user: REGISTRATION }, env: { "REMOTE_ADDR" => "203.0.113.10" }
      assert_response :see_other
    end

    assert_no_difference "User.count" do
      post user_registration_path, params: { **auth_form_fields, user: REGISTRATION }, env: { "REMOTE_ADDR" => "203.0.113.10" }
    end
    assert_response :too_many_requests
    assert_select "[role=alert]", text: AuthSpamProtection::RATE_LIMIT_MESSAGE

    assert_difference "User.count", 1 do
      post user_registration_path, params: { **auth_form_fields, user: REGISTRATION }, env: { "REMOTE_ADDR" => "203.0.113.11" }
    end
    assert_redirected_to confirmation_pending_path

    travel 61.minutes do
      post user_registration_path, params: { **auth_form_fields, form_note: "x", user: REGISTRATION }, env: { "REMOTE_ADDR" => "203.0.113.10" }
      assert_response :see_other
    end
  end

  test "password, confirmation, and unlock requests are limited to 5 per 15 minutes per IP" do
    { user_password_path => users(:member).email,
      user_confirmation_path => @unconfirmed.email,
      user_unlock_path => @locked.email }.each do |path, email|
      5.times do
        post path, params: { **auth_form_fields, form_note: "x", user: { email: email } }, env: { "REMOTE_ADDR" => "198.51.100.7" }
        assert_response :see_other
      end

      assert_nothing_sent do
        post path, params: { **auth_form_fields, user: { email: email } }, env: { "REMOTE_ADDR" => "198.51.100.7" }
      end
      assert_response :too_many_requests, path
      assert_select "[role=alert]", text: AuthSpamProtection::RATE_LIMIT_MESSAGE
    end
  end

  test "registration renders Turnstile only when both keys are configured and never exposes the secret" do
    get new_user_registration_path
    assert_select "[data-controller=turnstile]", 0
    assert_not_includes response.body, "challenges.cloudflare.com"

    enable_turnstile
    get new_user_registration_path
    assert_select "#registration-form [data-controller=turnstile][data-turnstile-site-key-value=?]", "site-key-public"
    assert_select "meta[name=turbo-cache-control][content=no-cache]"
    assert_not_includes response.body, "secret-key-private"

    get new_user_password_path
    assert_select "[data-controller=turnstile]", 0
  end

  test "registration rejects a failed Turnstile check and fails open when Cloudflare is unavailable" do
    enable_turnstile
    calls = []
    verifier = ->(token:, remote_ip:) { calls << [ token, remote_ip ]; @turnstile_result }

    TurnstileVerifier.stub(:verify, verifier) do
      @turnstile_result = :failure
      assert_no_difference "User.count" do
        assert_nothing_sent do
          post user_registration_path, params: { **auth_form_fields, "cf-turnstile-response" => "bad", user: REGISTRATION }
        end
      end
      assert_response :unprocessable_entity
      assert_select "[role=alert]", text: AuthSpamProtection::TURNSTILE_MESSAGE
      assert_select "[data-controller=turnstile]"

      @turnstile_result = :unavailable
      assert_difference "User.count", 1 do
        post user_registration_path, params: { **auth_form_fields, "cf-turnstile-response" => "maybe", user: REGISTRATION }
      end
      assert_redirected_to confirmation_pending_path

      @turnstile_result = :success
      assert_difference "User.count", 1 do
        assert_enqueued_email_with RegistrationMailer, :new_registration, args: ->(args) { args.first.email == "turnstile-ok@example.com" } do
          post user_registration_path, params: { **auth_form_fields, "cf-turnstile-response" => "good", user: REGISTRATION.merge(email: "turnstile-ok@example.com") }
        end
      end
      assert_redirected_to confirmation_pending_path

      # Obvious bots never reach Cloudflare.
      post user_registration_path, params: { **auth_form_fields, form_note: "x", user: REGISTRATION }
      post user_registration_path, params: { **auth_form_fields(rendered_at: Time.current), user: REGISTRATION }
    end

    assert_equal [ [ "bad", "127.0.0.1" ], [ "maybe", "127.0.0.1" ], [ "good", "127.0.0.1" ] ], calls
  end

  test "password and confirmation forms do not require Turnstile" do
    enable_turnstile
    TurnstileVerifier.stub(:verify, ->(**) { flunk "Turnstile must only guard registration" }) do
      post user_password_path, params: { **auth_form_fields, user: { email: users(:member).email } }
      assert_redirected_to new_user_session_path
    end
  end

  test "rejections are logged with reason and request id but without submitted values" do
    output = StringIO.new
    original_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(output)
    post user_registration_path, params: { **auth_form_fields, form_note: "honeypot-value", user: REGISTRATION }
    post user_password_path, params: { form_note: "", user: { email: users(:member).email } }
  ensure
    Rails.logger = original_logger
    log = output.string
    assert_match(/\[auth_spam_protection\] rejected endpoint=users\/registrations#create reason=honeypot request_id=\S+/, log)
    assert_match(/\[auth_spam_protection\] rejected endpoint=users\/passwords#create reason=timing request_id=\S+/, log)
    [ "honeypot-value", REGISTRATION[:email], users(:member).email, REGISTRATION[:password] ].each do |value|
      assert_not_includes log, value
    end
  end

  test "token-based password change, confirmation, and login are not affected" do
    raw_token = users(:member).send_reset_password_instructions
    put user_password_path, params: { user: { reset_password_token: raw_token, password: "new-password-1", password_confirmation: "new-password-1" } }
    assert_response :see_other
    assert users(:member).reload.valid_password?("new-password-1")
    delete destroy_user_session_path

    raw_confirmation = @unconfirmed.confirmation_token
    get user_confirmation_path(confirmation_token: raw_confirmation)
    assert @unconfirmed.reload.confirmed?
    delete destroy_user_session_path

    post user_session_path, params: { user: { email: users(:admin).email, password: "password123" } }
    assert_response :see_other
  end

  private

  def enable_turnstile
    ENV["TURNSTILE_SITE_KEY"] = "site-key-public"
    ENV["TURNSTILE_SECRET_KEY"] = "secret-key-private"
  end

  def assert_nothing_sent(&block)
    assert_no_emails do
      assert_no_enqueued_emails(&block)
    end
  end
end
