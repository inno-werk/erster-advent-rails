class PrintProduct < ApplicationRecord
  has_one_attached :image
  has_many :print_order_items, dependent: :restrict_with_error

  validates :title, :description, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :active, inclusion: { in: [ true, false ] }
  validate :image_is_web_image

  scope :available, -> { where(active: true) }
  scope :ordered, -> { order(:position, :id) }

  private

  def image_is_web_image
    return unless image.attached?
    return if %w[image/jpeg image/png image/webp image/gif].include?(image.blob.content_type) && image.blob.byte_size <= 10.megabytes

    errors.add(:image, "muss ein Bild (JPEG, PNG, WebP oder GIF) mit höchstens 10 MB sein.")
  end
end
