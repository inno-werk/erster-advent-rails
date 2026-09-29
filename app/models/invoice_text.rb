# Saved email subject and invoice text for one event year. Without a saved
# row the defaults of the year are used. The text names the year, so it is
# stored per year and never carried over to the next event.
class InvoiceText < ApplicationRecord
  belongs_to :updated_by, class_name: "User", optional: true

  validates :year, numericality: { only_integer: true, in: 2000..9999 }, uniqueness: true
  validates :subject, presence: true, length: { maximum: InvoiceRun::MAX_SUBJECT_LENGTH }
  validates :message, presence: true, length: { maximum: InvoiceRun::MAX_MESSAGE_LENGTH }
  validate :fits_invoice_layout

  normalizes :subject, with: ->(value) { value.to_s.squish }
  normalizes :message, with: ->(value) { value.to_s.gsub("\r\n", "\n").strip }

  def self.human_attribute_name(attribute, options = {})
    { "subject" => "Betreff", "message" => "Text" }.fetch(attribute.to_s) { super }
  end

  def self.for_year(year)
    find_by(year: year) || new(year: year, subject: InvoiceRun.default_subject(year), message: InvoiceRun.default_message(year))
  end

  # True when the browser submitted exactly the text that is saved (or the
  # default), i.e. the admin sent what they reviewed.
  def matches?(subject, message)
    self.class.new(subject: subject, message: message).then { |other| other.subject == self.subject && other.message == self.message }
  end

  private

  # Render a sample invoice so an unsupported character or a text that does
  # not fit the page is reported when saving, not when sending.
  def fits_invoice_layout
    return if message.blank? || errors.include?(:message)

    run = InvoiceRun.new(year: year, subject: subject.presence || "–", message: message, creditor: InvoiceSetting.current.snapshot, created_at: Time.current)
    sample = ParticipationInvoice.new(invoice_run: run, year: year, category: "non_leist_member", amount_cents: 25_000,
      recipient_name: "Beispiel", recipient_address: "Musterstrasse 1\n3011 Bern", recipient_email: "beispiel@example.com")
    ParticipationInvoicePdf.new(sample).render
  rescue ParticipationInvoicePdf::LayoutError, SwissQrBill::InvalidData => error
    errors.add(:base, error.message)
  end
end
