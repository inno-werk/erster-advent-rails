class Participation < ApplicationRecord
  CATEGORIES = {
    "leist_member" => {
      title: "Leistmitglied", amount_cents: 20_000,
      description: "Sind Sie mit Ihrem Geschäft aktives Leistmitglied? Dann reduziert sich der Teilnahmebeitrag um CHF 50.00. Sie werden auf der Website und dem Online-Stadtplan aufgeführt und im gedruckten Stadtplan eingetragen."
    }.freeze,
    "non_leist_member" => {
      title: "Nicht-Leistmitglied", amount_cents: 25_000,
      description: "Sind Sie mit Ihrem Geschäft kein aktives Mitglied des Leistes, beteiligen Sie sich mit dem ordentlichen Beitrag am koordinierten Sonntagsverkauf. Sie werden auf der Website und dem Online-Stadtplan aufgeführt und im gedruckten Stadtplan eingetragen."
    }.freeze,
    "no_listing" => {
      title: "Kein Eintrag", amount_cents: 10_000,
      description: "Reduzierter Beitrag unabhängig der Leistmitgliedschaft. Sie möchten Ihr Geschäft am Ersten Advent für das Publikum öffnen, verzichten aber auf die Erwähnung auf den Kommunikationsmitteln (keine Erwähnung auf der Website, dem Online-Stadtplan und kein Eintrag im gedruckten Stadtplan)."
    }.freeze
  }.freeze
  LISTED_CATEGORIES = %w[leist_member non_leist_member].freeze

  belongs_to :user
  has_many :upgrades, class_name: "ParticipationUpgrade", dependent: :destroy
  has_many :stripe_payments, dependent: :destroy
  enum :payment_status, { pending: "pending", paid: "paid" }, validate: true

  validates :year, numericality: { only_integer: true, in: 2000..9999 }, uniqueness: { scope: :user_id }
  validates :category, inclusion: { in: CATEGORIES.keys }
  validates :amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :selected_at, presence: true
  validates :paid_at, presence: true, if: :paid?
  validates :paid_at, absence: true, if: :pending?
  validate :protect_paid_snapshot
  validate :protect_ownership

  before_validation :snapshot_category, if: -> { new_record? || will_save_change_to_category? }

  scope :for_year, ->(year = EventConfiguration.year) { where(year: year) }
  # Members who explicitly booked «Kein Eintrag» opt out of every public listing.
  scope :listing_opted_out, -> { for_year.where(category: "no_listing") }

  def category_title
    CATEGORIES.dig(category, :title) || "Noch nicht ausgewählt"
  end

  def complete?
    paid?
  end

  def permits_listing?
    LISTED_CATEGORIES.include?(category)
  end

  def pending_upgrade
    upgrade = upgrades.pending.first
    upgrade if upgrade&.payable?
  end

  def upgrade_categories
    return {} unless paid? && category == "no_listing"

    CATEGORIES.select { |key, details| LISTED_CATEGORIES.include?(key) && details[:amount_cents] > amount_cents }
  end

  def upgrade_available?
    paid? && upgrade_categories.any? && !pending_upgrade
  end

  def payment_due?
    pending? || pending_upgrade.present?
  end

  def amount_due_cents
    pending? ? amount_cents : (pending_upgrade&.difference_cents || 0)
  end

  def last_payment_at
    upgrades.paid.maximum(:paid_at) || paid_at
  end

  def simulated_payment?
    (paid? && payment_provider == "dummy") || upgrades.paid.where(payment_provider: "dummy").exists?
  end

  def request_upgrade(category)
    with_lock do
      existing = upgrades.pending.first
      return existing if existing&.category == category && existing.payable?

      upgrade = upgrades.build(category: category)
      if existing
        upgrade.errors.add(:base, "Bitte bezahlen Sie zuerst die bereits gewählte Erhöhung.")
      else
        upgrade.save
      end
      upgrade
    end
  end

  def confirm_upgrade!(upgrade_id)
    with_lock do
      upgrade = upgrades.lock.find(upgrade_id)
      return if upgrade.paid?
      unless upgrade.payable?
        errors.add(:base, "Die Erhöhung passt nicht mehr zur bezahlten Mitgliedschaft.")
        raise ActiveRecord::RecordInvalid, self
      end

      @applying_upgrade = true
      update!(category: upgrade.category, amount_cents: upgrade.amount_cents, selected_at: Time.current)
      upgrade.update!(payment_status: :paid, paid_at: Time.current)
    end
  ensure
    @applying_upgrade = false
  end

  # Future payment integration: after verifying an authenticated provider event
  # and matching its amount/currency/reference, call this under a record lock.
  # The only user-facing exception is the explicitly enabled dummy payment.
  def mark_paid!
    with_lock { update!(payment_status: :paid, paid_at: paid_at || Time.current) }
  end

  def mark_unpaid!
    with_lock do
      if upgrades.exists?
        errors.add(:base, "Bei einer Mitgliedschaft mit Erhöhungen kann die ursprüngliche Zahlung nicht pauschal zurückgesetzt werden.")
        raise ActiveRecord::RecordInvalid, self
      end
      update!(payment_status: :pending, paid_at: nil)
    end
  end

  private

  def snapshot_category
    return if @applying_upgrade
    return unless CATEGORIES.key?(category)

    self.amount_cents = CATEGORIES.fetch(category).fetch(:amount_cents)
    self.selected_at = Time.current
  end

  def protect_paid_snapshot
    return if @applying_upgrade
    return unless persisted? && (payment_status_in_database == "paid" || paid?)
    return unless will_save_change_to_category? || will_save_change_to_amount_cents? || will_save_change_to_selected_at?

    errors.add(:base, "Eine bezahlte Teilnahme kann nicht umgebucht werden.")
  end

  def protect_ownership
    return unless persisted? && (will_save_change_to_user_id? || will_save_change_to_year?)

    errors.add(:base, "Benutzer und Teilnahmejahr können nicht geändert werden.")
  end
end
