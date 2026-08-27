class PrintOrderItem < ApplicationRecord
  belongs_to :print_order, inverse_of: :items, touch: true
  belongs_to :print_product

  validates :quantity, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 100_000 }
  validates :print_product_id, uniqueness: { scope: :print_order_id }
end
