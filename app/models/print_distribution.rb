class PrintDistribution < ApplicationRecord
  validates :year, numericality: { only_integer: true, in: 2000..9999 }, uniqueness: true
  validate :valid_distribution_date
  validate :valid_order_deadline
  validate :deadline_precedes_distribution

  def self.current
    find_or_initialize_by(year: EventConfiguration.year)
  end

  def orders_open?(on: Time.current.in_time_zone("Europe/Zurich").to_date)
    order_deadline_on.nil? || on <= order_deadline_on
  end

  private

  def valid_distribution_date
    if distribution_on_before_type_cast.present? && distribution_on.nil?
      errors.add(:distribution_on, "muss ein gültiges Datum sein")
    end
  end

  def valid_order_deadline
    if order_deadline_on_before_type_cast.present? && order_deadline_on.nil?
      errors.add(:order_deadline_on, "muss ein gültiges Datum sein")
    end
  end

  def deadline_precedes_distribution
    return if order_deadline_on.nil? || distribution_on.nil? || order_deadline_on <= distribution_on

    errors.add(:order_deadline_on, "muss am oder vor dem Verteildatum liegen")
  end
end
