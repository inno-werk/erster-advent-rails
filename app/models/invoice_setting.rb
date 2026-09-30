# Bank details and letterhead printed on participation invoices.
#
# There is exactly one row; `current` reads it or an unsaved record prefilled
# with the association's details. Invoices can only be sent from a saved row.
class InvoiceSetting < ApplicationRecord
  DEFAULTS = {
    creditor_name: "Erster Advent Untere Altstadt Bern",
    street: "Wasserwerkgasse",
    building_number: "29",
    postal_code: "3011",
    town: "Bern",
    country: "CH",
    iban: "CH96 0079 0016 6004 9421 8",
    bank_name: "Berner Kantonalbank",
    letterhead: <<~TEXT.strip
      Verein Erster Advent Untere Altstadt Bern
      c/o Kargo Kommunikation GmbH
      Wasserwerkgasse 29
      3011 Bern
      +41 31 311 76 66
      info@erster-advent-bern.ch
      www.erster-advent-bern.ch
    TEXT
  }.freeze

  # Field lengths of the Swiss Payment Standards (IG QR-bill, structured address).
  LIMITS = { creditor_name: 70, street: 70, building_number: 16, postal_code: 16, town: 35, bank_name: 70 }.freeze
  MAX_LETTERHEAD_LINES = 8

  normalizes :iban, with: ->(value) { value.to_s.gsub(/\s+/, "").upcase }
  normalizes :country, with: ->(value) { value.to_s.strip.upcase }
  normalizes :creditor_name, :street, :building_number, :postal_code, :town, :bank_name,
    with: ->(value) { value.to_s.squish }
  normalizes :letterhead, with: ->(value) { value.to_s.lines.map(&:strip).reject(&:blank?).join("\n") }

  validates :creditor_name, :street, :postal_code, :town, :country, :iban, :bank_name, presence: true
  LIMITS.each { |field, maximum| validates field, length: { maximum: maximum } }
  validates :country, inclusion: { in: %w[CH LI], message: "muss CH oder LI sein" }
  validates :letterhead, length: { maximum: 600 }
  validate :valid_iban
  validate :qr_character_set
  validate :letterhead_lines

  ATTRIBUTE_NAMES = {
    "creditor_name" => "Kontoinhaber", "street" => "Strasse", "building_number" => "Hausnummer", "postal_code" => "PLZ",
    "town" => "Ort", "country" => "Land", "iban" => "IBAN", "bank_name" => "Bank", "letterhead" => "Briefkopf"
  }.freeze

  def self.human_attribute_name(attribute, options = {})
    ATTRIBUTE_NAMES.fetch(attribute.to_s) { super }
  end

  def self.current
    first || new(DEFAULTS)
  end

  # Values frozen into an invoice run so every invoice of a run shows the
  # same account even if the settings change while emails are sent.
  def snapshot
    attributes.slice("creditor_name", "street", "building_number", "postal_code", "town", "country", "iban", "bank_name", "letterhead")
  end

  def self.formatted_iban(iban)
    iban.to_s.scan(/.{1,4}/).join(" ")
  end

  private

  def valid_iban
    return if iban.blank?

    unless iban.match?(/\A(CH|LI)\d{7}[0-9A-Z]{12}\z/)
      errors.add(:iban, "muss eine Schweizer oder Liechtensteiner IBAN mit 21 Zeichen sein")
      return
    end
    numeric = "#{iban[4..]}#{iban[0, 4]}".gsub(/[A-Z]/) { |letter| (letter.ord - 55).to_s }
    return errors.add(:iban, "hat eine ungültige Prüfziffer") unless numeric.to_i % 97 == 1

    # A QR-IBAN (institution ID 30000–31999) requires a QR reference, which
    # these invoices do not use.
    errors.add(:iban, "ist eine QR-IBAN. Bitte die normale IBAN des Kontos erfassen") if (30_000..31_999).cover?(iban[4, 5].to_i)
  end

  def qr_character_set
    %i[creditor_name street building_number postal_code town].each do |field|
      value = public_send(field).to_s
      errors.add(field, "enthält Zeichen, die in der QR-Rechnung nicht erlaubt sind") unless SwissQrBill.valid_text?(value)
    end
  end

  def letterhead_lines
    errors.add(:letterhead, "darf höchstens #{MAX_LETTERHEAD_LINES} Zeilen haben") if letterhead.to_s.lines.size > MAX_LETTERHEAD_LINES
  end
end
