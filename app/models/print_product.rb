class PrintProduct < ApplicationRecord
  include WebImageAttachments

  has_one_attached :image
  has_many :print_order_items, dependent: :restrict_with_error

  validates :title, :description, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :active, inclusion: { in: [ true, false ] }
  validates_web_image :image

  scope :available, -> { where(active: true) }
  scope :ordered, -> { order(:position, :id) }
end
