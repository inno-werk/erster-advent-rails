# Site-wide settings that the admin can change without a deploy.
#
# There is exactly one row; `current` reads it (or an unsaved default, so a
# database that has not been seeded yet still renders).
class SiteSetting < ApplicationRecord
  # The brand colour of the current year. It is injected over daisyUI's
  # `--color-primary`, so every `primary` utility in the theme follows it.
  DEFAULT_BRAND_COLOR = "#52819C".freeze

  HEX_COLOR = /\A#(?:\h{3}|\h{6})\z/

  validates :brand_color, presence: true, format: {
    with: HEX_COLOR,
    message: "muss ein Hex-Farbwert sein, z. B. #52819C"
  }

  before_validation :normalize_brand_color

  def self.current
    first || new(brand_color: DEFAULT_BRAND_COLOR)
  end

  def self.brand_color
    current.brand_color
  end

  private

  def normalize_brand_color
    return if brand_color.blank?

    self.brand_color = brand_color.strip.upcase
    self.brand_color = "##{brand_color}" unless brand_color.start_with?("#")
  end
end
