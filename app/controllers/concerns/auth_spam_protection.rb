# Spam protection for public Devise forms that create accounts or send mail.
#
# Every protected `create` action is rate-limited per client IP and requires an
# empty honeypot field plus a signed render timestamp that proves a minimum fill
# time. Controllers can additionally require Cloudflare Turnstile.
#
# Including controllers implement:
# - `respond_to_spam_as_success`: the same redirect a successful submission gives;
# - `build_auth_form_resource`: assigns `resource` from non-secret params so the
#   form can be re-rendered.
module AuthSpamProtection
  extend ActiveSupport::Concern

  HONEYPOT_PARAM = :form_note
  TIMESTAMP_PARAM = :form_rendered_at
  TOKEN_PURPOSE = :auth_form_rendered_at
  MIN_FILL_TIME = 3.seconds
  MAX_FORM_AGE = 24.hours

  RETRY_MESSAGE = "Das Formular konnte nicht gesendet werden. Bitte prüfen Sie Ihre Angaben und senden Sie es erneut."
  TURNSTILE_MESSAGE = "Bitte bestätigen Sie die Sicherheitsprüfung und senden Sie das Formular erneut."
  RATE_LIMIT_MESSAGE = "Zu viele Anfragen. Bitte versuchen Sie es in einigen Minuten erneut."

  # Rails evaluates a rate limit's store when the controller class loads; this
  # proxy keeps the store swappable (production: Rails.cache, tests: MemoryStore).
  # A broken cache database must not block sign-ups: counting fails open (nil
  # means "not limited") and is logged without the key, which contains the IP.
  class RateLimitStore
    attr_writer :backend

    def backend
      @backend || Rails.cache
    end

    def increment(name, amount = 1, **options)
      backend.increment(name, amount, **options)
    rescue ActiveRecord::ActiveRecordError => error
      report_failure(error)
    rescue ArgumentError => error
      raise unless error.message == "No unique index found for key_hash"

      report_failure(error)
    end

    private

    def report_failure(error)
      Rails.logger.error("[auth_spam_protection] rate limit counter unavailable (#{error.class}); check Solid Cache database migrations.")
      nil
    end
  end

  def self.rate_limit_store
    @rate_limit_store ||= RateLimitStore.new
  end

  def self.form_token(now = Time.current)
    verifier.generate(now.to_f, purpose: TOKEN_PURPOSE, expires_at: now + MAX_FORM_AGE)
  end

  def self.rendered_at(token, now: Time.current)
    return unless token.is_a?(String) && token.present?

    value = verifier.verified(token, purpose: TOKEN_PURPOSE)
    return unless value.is_a?(Numeric)

    time = Time.zone.at(value)
    time if now - time <= MAX_FORM_AGE
  rescue ArgumentError
    nil
  end

  def self.verifier
    Rails.application.message_verifier(:auth_spam_protection)
  end

  included do
    class_attribute :auth_form_turnstile, instance_writer: false, default: false
  end

  class_methods do
    def protect_auth_form(limit:, within:, turnstile: false)
      self.auth_form_turnstile = turnstile
      rate_limit to: limit, within: within, only: :create,
        store: AuthSpamProtection.rate_limit_store,
        with: -> { reject_rate_limited_auth_form }
      before_action :verify_auth_form_submission, only: :create
    end
  end

  private

  def verify_auth_form_submission
    if params[HONEYPOT_PARAM].present?
      log_auth_form_rejection(:honeypot)
      return respond_to_spam_as_success
    end

    rendered_at = AuthSpamProtection.rendered_at(params[TIMESTAMP_PARAM])
    if rendered_at.nil? || Time.current - rendered_at < MIN_FILL_TIME
      log_auth_form_rejection(:timing)
      return render_auth_form_retry(RETRY_MESSAGE)
    end

    return unless auth_form_turnstile && TurnstileVerifier.enabled?

    result = TurnstileVerifier.verify(token: params[TurnstileVerifier::RESPONSE_PARAM], remote_ip: request.remote_ip)
    return unless result == :failure

    log_auth_form_rejection(:turnstile)
    render_auth_form_retry(TURNSTILE_MESSAGE)
  end

  def render_auth_form_retry(message)
    build_auth_form_resource
    resource.errors.add(:base, message)
    clean_up_passwords(resource)
    set_minimum_password_length
    render :new, status: :unprocessable_entity
  end

  def reject_rate_limited_auth_form
    log_auth_form_rejection(:rate_limit)
    render "devise/shared/rate_limited", layout: "auth", status: :too_many_requests
  end

  def log_auth_form_rejection(reason)
    Rails.logger.info(
      "[auth_spam_protection] rejected endpoint=#{controller_path}##{action_name} " \
      "reason=#{reason} request_id=#{request.request_id}"
    )
  end

  def submitted_auth_email
    submitted = params[resource_name]
    email = submitted[:email] if submitted.is_a?(ActionController::Parameters)
    email if email.is_a?(String)
  end

  def respond_to_spam_as_success
    raise NotImplementedError, "#{self.class} must implement #respond_to_spam_as_success"
  end

  def build_auth_form_resource
    raise NotImplementedError, "#{self.class} must implement #build_auth_form_resource"
  end
end
