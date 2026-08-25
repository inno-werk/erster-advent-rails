# A single editable section of the frontpage.
#
# Blocks come in four flavours, matching the four section designs the
# frontpage supports. `faq_item` is special: those rows are not sections of
# their own, they are the rows inside the one fixed FAQ section rendered at
# the bottom of the page.
class CmsBlock < ApplicationRecord
  PAGES = %w[home].freeze
  IMAGE_POSITIONS = %w[left right].freeze

  # Section blocks, in the order they are offered in the admin UI.
  SECTION_TYPES = %w[text_image_block full_image_block plain_text_block].freeze

  has_rich_text :title
  has_rich_text :content

  has_one_attached :image

  enum :block_type, {
    text_image_block: 0,
    full_image_block: 1,
    plain_text_block: 2,
    faq_item: 3
  }, default: :text_image_block

  validates :page, presence: true, inclusion: { in: PAGES }
  validates :block_type, presence: true
  validates :image_position, inclusion: { in: IMAGE_POSITIONS }
  validates :question, presence: true, if: :faq_item?
  validates :image, presence: true, if: :full_image_block?
  validate :button_needs_text_and_url

  scope :for_page, ->(page) { where(page: page) }
  scope :active, -> { where(is_active: true) }
  scope :ordered, -> { order(:position, :id) }
  scope :sections, -> { where(block_type: SECTION_TYPES) }
  scope :faq_items, -> { where(block_type: :faq_item) }

  before_validation :assign_default_position, on: :create

  def section?
    !faq_item?
  end

  def image_left?
    image_position != "right"
  end

  def button?
    button_text.present? && button_url.present?
  end

  # Swaps this block with its neighbour of the same kind, so reordering
  # sections never interleaves them with FAQ rows.
  def move!(direction)
    self.class.normalize_positions!(page)
    reload

    siblings = self.class.for_page(page).ordered.to_a.select { |b| b.faq_item? == faq_item? }
    index = siblings.index(self)
    neighbour_index = direction.to_s == "up" ? index - 1 : index + 1
    return false if neighbour_index.negative?

    neighbour = siblings[neighbour_index]
    return false if neighbour.nil?

    own_position, neighbour_position = position, neighbour.position
    transaction do
      update_column(:position, neighbour_position)
      neighbour.update_column(:position, own_position)
    end
    true
  end

  # Positions are only ever compared, never displayed, but keeping them dense
  # and unique makes a neighbour swap meaningful.
  def self.normalize_positions!(page)
    for_page(page).ordered.each.with_index(1) do |block, position|
      block.update_column(:position, position) unless block.position == position
    end
  end

  # Short label used in the admin overview list.
  def admin_label
    case block_type
    when "faq_item" then question.to_s.truncate(80)
    when "full_image_block" then image.attached? ? image.filename.to_s : "Kein Bild"
    else title&.to_plain_text.to_s.squish.truncate(80).presence || "Ohne Titel"
    end
  end

  private

  # The column carries a DB default of 0, so `||=` would never fire; treat
  # anything non-positive as "append to the end".
  def assign_default_position
    return if position.to_i.positive?

    self.position = self.class.for_page(page).maximum(:position).to_i + 1
  end

  def button_needs_text_and_url
    return unless text_image_block?
    return if button_text.blank? && button_url.blank?
    return if button?

    errors.add(:button_url, "und Button-Text müssen zusammen ausgefüllt werden")
  end
end
