class PrintOrder < ApplicationRecord
  belongs_to :user
  has_many :items, class_name: "PrintOrderItem", dependent: :destroy, inverse_of: :print_order, autosave: true

  validates :year, numericality: { only_integer: true, in: 2000..9999 }, uniqueness: { scope: :user_id }
  scope :for_year, ->(year = EventConfiguration.year) { where(year: year) }

  # Only products in the caller's allowed catalogue can be changed. Disabled
  # products already ordered remain visible and retain their quantities.
  def update_quantities(quantities, products:, maximum_quantity: nil)
    allowed = products.index_by { |product| product.id.to_s }
    if (quantities.keys.map(&:to_s) - allowed.keys).any?
      errors.add(:base, "Ein ausgewähltes Printprodukt ist nicht verfügbar.")
      return false
    end

    quantities.each do |product_id, raw_quantity|
      item = items.find { |existing| existing.print_product_id.to_s == product_id.to_s }
      if raw_quantity.to_s.match?(/\A0*\z/)
        item&.mark_for_destruction
      else
        item ||= items.build(print_product: allowed.fetch(product_id.to_s))
        item.quantity = raw_quantity
      end
    end
    if maximum_quantity && items.any? { |item| !item.marked_for_destruction? && quantities.key?(item.print_product_id.to_s) && item.quantity.to_i > maximum_quantity }
      errors.add(:base, "Bitte wählen Sie pro Produkt zwischen 1 und #{maximum_quantity} Bündeln.")
      return false
    end
    save
  end
end
