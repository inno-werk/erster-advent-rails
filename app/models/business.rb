class Business < ApplicationRecord
   include PgSearch::Model

  pg_search_scope :search, against: [ :business_name, :address ],
    associated_against: {
      rich_text_description: :body
    },
    using: {
      tsearch: { prefix: true }
    }
  belongs_to :user
  has_many :participations, through: :user
  has_many :products, through: :user

  has_one_attached :main_image
  has_one_attached :image_gallery1
  has_one_attached :image_gallery2
  has_one_attached :image_gallery3

  has_rich_text :description
  has_rich_text :first_advent_specialities

  validates :business_name, :phone, :address, :billing_address, presence: true

  # Only the domain is stored; "https://" is shown in the form and added for links.
  normalizes :website, with: ->(value) { value.strip.sub(%r{\A(?:https?://)+}i, "") }


  attribute :tags, :json, default: []
  attribute :categories, :json, default: []

  enum :status, [ :pending, :confirmed, :rejected, :deleted ], default: :pending, validate: true

  # Use this scope for every public listing, search, detail page, and map/export.
  # Admin approval decides visibility; only an explicit «Kein Eintrag» membership opts out.
  scope :publicly_visible, -> {
    confirmed.joins(:user).merge(User.active)
      .where.not(user_id: Participation.listing_opted_out.select(:user_id))
  }

  # Rows saved before the domain-only change may still carry a scheme.
  def website_url
    return if website.blank?

    "https://#{website.sub(%r{\A(?:https?://)+}i, "")}"
  end

  def publicly_visible?
    persisted? && self.class.publicly_visible.exists?(id: id)
  end
end
