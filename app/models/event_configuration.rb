# One source of truth for the active participation period and distribution copy.
class EventConfiguration
  DEFAULT_DELIVERY_INFORMATION = "Die Printmaterialien werden an einem gemeinsamen Verteiltag vor dem Ersten Advent verteilt.".freeze

  def self.year
    # Missing config.x keys return empty OrderedOptions, not nil (notably in
    # development when an initializer was added after the server booted).
    configured = Rails.configuration.x.participation_year.presence || ENV["PARTICIPATION_YEAR"].presence
    configured ? Integer(configured.to_s, 10) : Date.current.year
  end

  def self.print_delivery_information
    Rails.configuration.x.print_delivery_information.presence || ENV["PRINT_DELIVERY_INFORMATION"].presence || DEFAULT_DELIVERY_INFORMATION
  end

  def self.dummy_payments_enabled?
    Rails.env.development? || Rails.env.test?
  end
end
