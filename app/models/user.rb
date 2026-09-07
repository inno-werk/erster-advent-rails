class User < ApplicationRecord
  include PgSearch::Model
  attr_accessor :account_email_preview_message, :registration_form
  attr_writer :registration_street_address, :registration_postal_city
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
  validates :name, :registration_street_address, :registration_postal_city,
    presence: true, if: :registration_form
  validates :phone,
    presence: true,
    format: {
      with: /\A\+?\d+\z/,
      message: "darf nur Ziffern und ein führendes + enthalten",
      allow_blank: true
    },
    if: :registration_form

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

  def active_for_authentication?
    super && !deleted?
  end

  def inactive_message
    deleted? ? :deleted : super
  end

  def build_registration_business
    full_address = registration_full_address.presence || address

    business || build_business(
      business_name: business_name,
      phone: phone,
      address: registration_street_address.presence || address,
      billing_address: full_address,
      email: email,
      contact_name: name.to_s,
      map_link: ""
    )
  end

  def registration_street_address
    return @registration_street_address if defined?(@registration_street_address)

    address.to_s.lines.first.to_s.strip
  end

  def registration_postal_city
    return @registration_postal_city if defined?(@registration_postal_city)

    address.to_s.lines.drop(1).join(" ").strip
  end

  def registration_full_address
    [ registration_street_address, registration_postal_city ]
      .map { |part| part.to_s.strip }
      .reject(&:blank?)
      .join("\n")
  end

  def business_for_editing
    with_lock do
      reload_business || build_registration_business.tap do |record|
        record.save! if record.valid?
      end
    end
  end

  private

  def send_devise_notification(notification, *args)
    return super if EmailDelivery.enabled?
    return unless AccountEmailPreview.enabled?

    # Keep Devise's real tokens and templates, but never contact SMTP in preview mode.
    # The controller only exposes this message after proving session ownership.
    self.account_email_preview_message = devise_mailer.public_send(notification, self, *args).message
  end

  def allowed_role_change
    return unless will_save_change_to_role?
    return if role_in_database == 1 && role == 2

    errors.add(:role, "kann nur von Admin zu Superadmin geändert werden.")
  end
end
