class StripeConfiguration
  class << self
    def ready?
      secret_key.present? && webhook_secret.present?
    end

    def secret_key
      ENV["STRIPE_SECRET_KEY"].presence
    end

    def webhook_secret
      ENV["STRIPE_WEBHOOK_SECRET"].presence
    end

    def client
      raise KeyError, "Stripe ist nicht vollständig konfiguriert." unless ready?

      Stripe::StripeClient.new(secret_key)
    end
  end
end
