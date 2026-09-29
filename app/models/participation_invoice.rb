# One emailed PDF invoice for the open participation amount of one member,
# created by an InvoiceRun. Recipient, amount and category are snapshotted
# when the run starts; delivery re-checks that the amount is still open.
class ParticipationInvoice < ApplicationRecord
  CATEGORY_CODES = { "leist_member" => "A", "non_leist_member" => "B", "no_listing" => "C" }.freeze
  MAX_ADDRESS_LINES = 4

  # An open amount of the active event year, before an invoice is created.
  Recipient = Data.define(:participation, :upgrade, :amount_cents) do
    def user = participation.user
    def business = user.business
    def email = user.email
    def category = upgrade ? upgrade.category : participation.category
    def previous_category = upgrade&.previous_category

    def name
      business&.business_name.presence || user.business_name.presence || user.name.to_s
    end

    def address_lines
      text = business&.billing_address.presence || business&.address.presence || user.address.to_s
      text.lines.map(&:strip).reject(&:blank?)
    end

    def problem
      if name.blank? then "Name des Geschäfts fehlt"
      elsif address_lines.empty? then "Rechnungsadresse fehlt"
      elsif address_lines.size > MAX_ADDRESS_LINES then "Rechnungsadresse hat mehr als #{MAX_ADDRESS_LINES} Zeilen"
      elsif !SwissQrBill.valid_text?([ name, *address_lines ].join(" ")) then "Name oder Adresse enthält nicht druckbare Zeichen"
      end
    end

    def fingerprint
      [ participation.id, upgrade&.id, amount_cents, category, email ].join(":")
    end
  end

  belongs_to :invoice_run
  belongs_to :participation
  belongs_to :participation_upgrade, optional: true
  belongs_to :user

  enum :status, { queued: "queued", sending: "sending", sent: "sent", failed: "failed", cancelled: "cancelled" }, validate: true

  validates :category, inclusion: { in: CATEGORY_CODES.keys }
  validates :previous_category, inclusion: { in: CATEGORY_CODES.keys }, allow_nil: true
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :recipient_email, :recipient_name, :recipient_address, presence: true

  # Every active-year participation of an active member with an open amount:
  # the full price while unpaid, otherwise the payable upgrade difference.
  def self.recipients(year = EventConfiguration.year)
    Participation.for_year(year).joins(:user).merge(User.active)
      .includes(:upgrades, user: :business).order(:id)
      .filter_map do |participation|
        upgrade = participation.pending? ? nil : participation.pending_upgrade
        amount = participation.pending? ? participation.amount_cents : upgrade&.difference_cents.to_i
        Recipient.new(participation: participation, upgrade: upgrade, amount_cents: amount) if amount.positive?
      end
  end

  # Fingerprint of the list the admin reviewed. A run is refused when the list
  # changed between rendering the page and submitting it.
  def self.recipients_digest(recipients)
    Digest::SHA256.hexdigest(recipients.map(&:fingerprint).sort.join("\n"))
  end

  def self.build_for(recipient, run)
    new(
      invoice_run: run,
      participation: recipient.participation,
      participation_upgrade: recipient.upgrade,
      user: recipient.user,
      year: recipient.participation.year,
      category: recipient.category,
      previous_category: recipient.previous_category,
      amount_cents: recipient.amount_cents,
      recipient_email: recipient.email,
      recipient_name: recipient.name,
      recipient_address: recipient.address_lines.join("\n")
    )
  end

  def self.last_sent_at_by_participation(participation_ids)
    sent.where(participation_id: participation_ids).group(:participation_id).maximum(:sent_at)
  end

  def upgrade?
    previous_category.present?
  end

  def category_code
    CATEGORY_CODES.fetch(category)
  end

  def previous_category_code
    CATEGORY_CODES.fetch(previous_category) if upgrade?
  end

  def category_title
    Participation::CATEGORIES.dig(category, :title)
  end

  def amount
    format("%d.%02d", amount_cents / 100, amount_cents % 100)
  end

  # «Betreff» cell of the position table.
  def position_title
    upgrade? ? "Differenz\nTeilnahmebeitrag\n#{year} / Kat. #{previous_category_code} zu #{category_code}" : "Teilnahmebeitrag\n#{year} / Kat. #{category_code}"
  end

  # «Zusätzliche Informationen» of the QR bill.
  def payment_message
    kind = upgrade? ? "Differenz Kategorie #{previous_category_code} zu #{category_code}" : "Kategorie #{category_code}"
    "Rechnung Erster Advent #{year}, #{kind}: CHF #{amount} (#{category_title})"
  end

  def filename
    name = recipient_name.to_s.parameterize.first(60).presence || "geschaeft"
    "Rechnung-Erster-Advent-#{year}-#{name}.pdf"
  end

  # True while the participation still owes exactly this amount.
  def still_due?
    current = Participation.includes(:upgrades).find_by(id: participation_id)
    return false unless current && current.year == year && !current.user.deleted?

    if participation_upgrade_id
      upgrade = current.pending_upgrade
      upgrade&.id == participation_upgrade_id && upgrade.difference_cents == amount_cents && upgrade.category == category
    else
      current.pending? && current.amount_cents == amount_cents && current.category == category
    end
  end

  # Moves a queued invoice to «sending» exactly once. Returns false when the
  # invoice must not be sent (already handled, disabled delivery, or paid).
  def claim_for_delivery!
    with_lock do
      return false unless queued?

      unless EmailDelivery.enabled?
        update!(status: :failed, error_message: "E-Mail-Versand ist deaktiviert (PROD_SEND ist nicht true).")
        return false
      end
      unless still_due?
        update!(status: :cancelled, error_message: "Nicht versendet: Der offene Betrag hat sich geändert oder wurde bezahlt.")
        return false
      end
      update!(status: :sending, error_message: nil)
      true
    end
  end

  def mark_sent!
    with_lock { update!(status: :sent, sent_at: Time.current, error_message: nil) if sending? }
  end

  def mark_failed!(error)
    with_lock { update!(status: :failed, error_message: "#{error.class}: #{error.message}".truncate(250)) if sending? }
  end

  # Only failed invoices may be queued again; sent ones never.
  def requeue!
    with_lock do
      return false unless failed?

      update!(status: :queued, error_message: nil)
      true
    end
  end
end
