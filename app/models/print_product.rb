class PrintProduct < ApplicationRecord
  include WebImageAttachments

  has_one_web_image :image, variants: %i[card]
  has_many :print_order_items, dependent: :restrict_with_error

  validates :title, :description, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :active, inclusion: { in: [ true, false ] }

  scope :available, -> { where(active: true) }
  scope :ordered, -> { order(:position, :id) }
end
