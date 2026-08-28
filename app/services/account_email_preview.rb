class AccountEmailPreview
  LIFETIME = 30.minutes

  # Sending is off by default; new test registrations use private browser previews.
  def self.enabled?
    ENV.fetch("PROD_SEND", "false") == "false"
  end

  def self.write(message, expires_at:)
    key = SecureRandom.hex(32)
    payload = {
      "from" => message[:from].decoded,
      "to" => message.to.join(", "),
      "subject" => message.subject,
      "html" => (message.html_part || message).body.decoded
    }
    encrypted = encryptor.encrypt_and_sign(payload, purpose: "account-email-preview", expires_at: expires_at)
    stored = cache_operation(:write) do
      Rails.cache.write("account-email-preview:#{key}", encrypted, expires_in: [ expires_at - Time.current, 0 ].max)
    end
    key if stored
  end

  def self.read(key)
    return unless enabled? && key.is_a?(String) && key.match?(/\A[0-9a-f]{64}\z/)

    encrypted = cache_operation(:read) { Rails.cache.read("account-email-preview:#{key}") }
    encryptor.decrypt_and_verify(encrypted, purpose: "account-email-preview") if encrypted
  rescue ActiveSupport::MessageEncryptor::InvalidMessage
    nil
  end

  def self.delete(key)
    cache_operation(:delete) { Rails.cache.delete("account-email-preview:#{key}") } if key.present?
  end

  def self.cache_operation(operation)
    yield
  rescue ActiveRecord::ActiveRecordError => error
    report_cache_failure(operation, error)
  rescue ArgumentError => error
    raise unless error.message == "No unique index found for key_hash"

    report_cache_failure(operation, error)
  end

  def self.report_cache_failure(operation, error)
    # Do not log cache contents: they contain email addresses and account tokens.
    Rails.logger.error("Account email preview cache #{operation} failed (#{error.class}); check Solid Cache database migrations.")
    nil
  end

  def self.encryptor
    secret = Rails.application.key_generator.generate_key("account-email-preview", 32)
    ActiveSupport::MessageEncryptor.new(secret, cipher: "aes-256-gcm", serializer: JSON)
  end
  private_class_method :encryptor, :cache_operation, :report_cache_failure
end
