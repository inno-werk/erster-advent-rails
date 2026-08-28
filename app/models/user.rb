class User < ApplicationRecord
  include PgSearch::Model
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :lockable, :trackable

  has_one :business, dependent: :destroy, autosave: true
  has_many :participations, dependent: :destroy
  has_many :print_orders, dependent: :destroy
  has_one :payment, dependent: :destroy
  has_many :products, dependent: :destroy
  has_many :customer_orders, class_name: "Order", foreign_key: :id_of_user, inverse_of: :customer, dependent: :destroy
  has_many :received_orders, through: :products, source: :orders

  validates :role, inclusion: { in: [ 0, 1, 2 ] }
  validate :allowed_role_change, on: :update

  scope :active, -> { where(deleted: false) }


  pg_search_scope :search,
    against: :email,
    using: {
      tsearch: { prefix: true, dictionary: "simple" }, # full-text, matches prefixes
      trigram: { threshold: 0.2 }                       # typo tolerance
    }

  def role_name
    case role
    when 0 then "User"
    when 1 then "Admin"
    when 2 then "Superadmin"
    else "Unknown"
    end
  end

  def user?       = role == 0
  def admin?      = role == 1
  def superadmin? = role == 2

  def adminish? = admin? || superadmin?

  def current_participation
    participations.for_year.first
  end

  def participation_complete?
    current_participation&.complete? || false
  end

  def business_editing_allowed?
    current_participation&.category != "no_listing"
  end

  def build_registration_business
    business || build_business(
      business_name: business_name,
      phone: phone,
      address: address,
      billing_address: address,
      email: email,
      contact_name: name.to_s,
      map_link: ""
    )
  end

  def business_for_editing
    with_lock do
      reload_business || build_registration_business.tap do |record|
        record.save! if record.valid?
      end
    end
  end

  private

  def allowed_role_change
    return unless will_save_change_to_role?
    return if role_in_database == 1 && role == 2

    errors.add(:role, "kann nur von Admin zu Superadmin geändert werden.")
  end
end
