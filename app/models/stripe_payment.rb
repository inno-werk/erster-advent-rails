class StripePayment < ApplicationRecord
  ACTIVE_STATUSES = %w[pending checkout_created processing].freeze

  belongs_to :participation
  belongs_to :participation_upgrade, optional: true

  enum :payment_kind, { initial: "initial", upgrade: "upgrade" }, validate: true
  enum :status, {
    pending: "pending", checkout_created: "checkout_created", processing: "processing",
    paid: "paid", failed: "failed", expired: "expired"
  }, validate: true

  validates :obligation_key, :idempotency_key, presence: true
  validates :idempotency_key, uniqueness: true
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :currency, inclusion: { in: %w[chf] }
  validates :attempt, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :obligation_key }
  validate :matching_payment_target

  scope :active, -> { where(status: ACTIVE_STATUSES) }

  def payable?
    if upgrade?
      participation_upgrade&.payable? && participation_upgrade.difference_cents == amount_cents
    else
      participation.pending? && participation.amount_cents == amount_cents
    end
  end

  def fulfill!(payment_intent_id: nil)
    transaction do
      lock!
      return if paid?
      raise ActiveRecord::RecordInvalid, self unless payable?

      if upgrade?
        participation_upgrade.mark_paid!
        participation_upgrade.update!(payment_provider: "stripe", payment_reference: payment_intent_id || checkout_session_id)
      else
        participation.mark_paid!
        participation.update!(payment_provider: "stripe", payment_reference: payment_intent_id || checkout_session_id)
      end
      update!(status: :paid, paid_at: Time.current, payment_intent_id: payment_intent_id || self.payment_intent_id)
    end
  end

  private

  def matching_payment_target
    if upgrade?
      errors.add(:participation_upgrade, "muss zur Teilnahme gehören") unless participation_upgrade&.participation_id == participation_id
    elsif participation_upgrade_id.present?
      errors.add(:participation_upgrade, "ist nur für eine Erhöhung erlaubt")
    end
  end
end
