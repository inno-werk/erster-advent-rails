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
    Rails.cache.write("account-email-preview:#{key}", encrypted, expires_in: [ expires_at - Time.current, 0 ].max)
    key
  end

  def self.read(key)
    return unless enabled? && key.is_a?(String) && key.match?(/\A[0-9a-f]{64}\z/)

    encrypted = Rails.cache.read("account-email-preview:#{key}")
    encryptor.decrypt_and_verify(encrypted, purpose: "account-email-preview") if encrypted
  rescue ActiveSupport::MessageEncryptor::InvalidMessage
    nil
  end

  def self.delete(key)
    Rails.cache.delete("account-email-preview:#{key}") if key.present?
  end

  def self.encryptor
    secret = Rails.application.key_generator.generate_key("account-email-preview", 32)
    ActiveSupport::MessageEncryptor.new(secret, cipher: "aes-256-gcm", serializer: JSON)
  end
  private_class_method :encryptor
end
