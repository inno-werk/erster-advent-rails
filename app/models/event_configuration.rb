# One source of truth for the active participation period and payment mode.
class EventConfiguration
  def self.year
    # Missing config.x keys return empty OrderedOptions, not nil (notably in
    # development when an initializer was added after the server booted).
    configured = Rails.configuration.x.participation_year.presence || ENV["PARTICIPATION_YEAR"].presence
    configured ? Integer(configured.to_s, 10) : Date.current.year
  end

  def self.dummy_payments_enabled?
    # Production must explicitly opt into simulated payments.
    return ENV["PROD_PAYMENT"] == "false" if ENV.key?("PROD_PAYMENT")

    Rails.env.development? || Rails.env.test?
  end
end
