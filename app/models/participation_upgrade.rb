class ParticipationUpgrade < ApplicationRecord
  belongs_to :participation
  has_many :stripe_payments, dependent: :restrict_with_error
  enum :payment_status, { pending: "pending", paid: "paid" }, validate: true

  validates :category, :previous_category, inclusion: { in: Participation::CATEGORIES.keys }
  validates :previous_amount_cents, :amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :difference_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :paid_at, presence: true, if: :paid?
  validates :paid_at, absence: true, if: :pending?
  validate :valid_initial_upgrade, on: :create
  validate :protect_snapshot, on: :update

  before_validation :snapshot_prices, on: :create

  def category_title
    Participation::CATEGORIES.dig(category, :title)
  end

  def mark_paid!
    participation.confirm_upgrade!(id)
    reload
  end

  def payable?
    pending? && participation.upgrade_categories.key?(category) &&
      participation.category == previous_category && participation.amount_cents == previous_amount_cents
  end

  private

  def snapshot_prices
    return unless participation && Participation::CATEGORIES.key?(category)

    self.previous_category = participation.category
    self.previous_amount_cents = participation.amount_cents
    self.amount_cents = Participation::CATEGORIES.fetch(category).fetch(:amount_cents)
    self.difference_cents = amount_cents - previous_amount_cents
  end

  def valid_initial_upgrade
    errors.add(:base, "Diese Mitgliedschaft kann nicht erhöht werden.") unless participation&.upgrade_categories&.key?(category)
    errors.add(:base, "Nur eine bezahlte Mitgliedschaft kann erhöht werden.") unless participation&.paid?
    errors.add(:base, "Die neue Mitgliedschaft muss einen höheren Beitrag haben.") if category == previous_category || difference_cents.to_i <= 0
    errors.add(:base, "Eine neue Erhöhung muss zuerst bezahlt werden.") unless pending?
  end

  def protect_snapshot
    if %w[participation_id previous_category previous_amount_cents category amount_cents difference_cents].any? { |field| will_save_change_to_attribute?(field) }
      errors.add(:base, "Eine angelegte Erhöhung kann nicht verändert werden.")
    end
    errors.add(:base, "Eine bestätigte Zahlung kann nicht zurückgesetzt werden.") if payment_status_in_database == "paid" && (will_save_change_to_payment_status? || will_save_change_to_paid_at?)
  end
end
