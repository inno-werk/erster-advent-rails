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


  attribute :tags, :json, default: []
  attribute :categories, :json, default: []

  enum :status, [ :pending, :confirmed, :rejected, :deleted ], default: :pending, validate: true

  # Use this scope for every public listing, search, detail page, and map/export.
  scope :publicly_visible, -> {
    confirmed.joins(:user).merge(User.active)
      .where(user_id: Participation.publicly_listable.select(:user_id))
  }

  def publicly_visible?
    persisted? && self.class.publicly_visible.exists?(id: id)
  end
end
