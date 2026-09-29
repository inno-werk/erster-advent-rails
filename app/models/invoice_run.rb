# One admin-triggered mailing of participation invoices for an event year.
#
# `start!` creates the run and one invoice per open amount in a single
# transaction, then queues one delivery job per invoice. A form can only start
# one run (unique idempotency key), and the run is refused when the reviewed
# recipient list no longer matches the server's list.
class InvoiceRun < ApplicationRecord
  class Refused < StandardError; end

  MAX_SUBJECT_LENGTH = 150
  MAX_MESSAGE_LENGTH = 1200

  belongs_to :created_by, class_name: "User", optional: true
  has_many :invoices, -> { order(:id) }, class_name: "ParticipationInvoice", dependent: :destroy, inverse_of: :invoice_run

  validates :year, numericality: { only_integer: true, in: 2000..9999 }
  validates :subject, presence: true, length: { maximum: MAX_SUBJECT_LENGTH }
  validates :message, presence: true, length: { maximum: MAX_MESSAGE_LENGTH }
  validates :idempotency_key, presence: true, uniqueness: true
  validate :creditor_present

  normalizes :subject, with: ->(value) { value.to_s.squish }
  normalizes :message, with: ->(value) { value.to_s.gsub("\r\n", "\n").strip }

  def self.default_subject(year)
    "Rechnung Teilnahmebeitrag Erster Advent #{year}"
  end

  def self.default_message(year)
    "Wir erlauben uns Ihnen hiermit den Teilnahmebeitrag für den Ersten Advent #{year} in Rechnung zu stellen " \
      "und möchten Ihnen an dieser Stelle danken, dass Sie den Anlass mit Ihrer Teilnahme bereichern und die " \
      "Organisation mit Ihrem Beitrag stützen."
  end

  # A run is still being delivered while invoices wait or are being sent. An
  # invoice stuck in «sending» (interrupted process) stops blocking after
  # 30 minutes; it stays visible on its run for manual checking.
  def self.in_progress?(year)
    ParticipationInvoice.joins(:invoice_run).where(invoice_runs: { year: year })
      .where(status: "queued").or(ParticipationInvoice.joins(:invoice_run).where(invoice_runs: { year: year }, status: "sending", updated_at: 30.minutes.ago..))
      .exists?
  end

  def self.start!(year:, subject:, message:, idempotency_key:, recipients_digest:, created_by:)
    existing = find_by(idempotency_key: idempotency_key.to_s)
    return existing if existing

    setting = InvoiceSetting.first
    raise Refused, "Bitte zuerst die Bankverbindung speichern." unless setting&.valid?
    raise Refused, "Der E-Mail-Versand ist deaktiviert (PROD_SEND ist nicht true). Es wurden keine Rechnungen versendet." unless EmailDelivery.enabled?
    raise Refused, "Ein Rechnungsversand für #{year} ist noch in Bearbeitung. Bitte warten, bis er abgeschlossen ist." if in_progress?(year)

    recipients = ParticipationInvoice.recipients(year)
    raise Refused, "Es gibt keine offenen Zahlungen für #{year}." if recipients.empty?
    raise Refused, "Bitte zuerst die fehlenden Angaben der markierten Geschäfte ergänzen." if recipients.any?(&:problem)
    unless ActiveSupport::SecurityUtils.secure_compare(recipients_digest.to_s, ParticipationInvoice.recipients_digest(recipients))
      raise Refused, "Die Liste der offenen Zahlungen hat sich inzwischen geändert. Bitte prüfen Sie die aktualisierte Liste und senden Sie erneut."
    end

    run = new(year: year, subject: subject, message: message, idempotency_key: idempotency_key,
      creditor: setting.snapshot, created_by: created_by)
    invoices = recipients.map { |recipient| ParticipationInvoice.build_for(recipient, run) }
    raise Refused, run.errors.full_messages.to_sentence unless run.valid?

    # Render one invoice before anything is stored, so a text that does not
    # fit the page is rejected instead of failing for every recipient.
    ParticipationInvoicePdf.new(invoices.first).render

    transaction do
      run.save!
      invoices.each(&:save!)
    end
    run.invoices.each { |invoice| ParticipationInvoiceDeliveryJob.perform_later(invoice.id) }
    run
  rescue ActiveRecord::RecordNotUnique
    find_by!(idempotency_key: idempotency_key.to_s)
  rescue ParticipationInvoicePdf::LayoutError, SwissQrBill::InvalidData => error
    raise Refused, error.message
  end

  # Queue failed invoices again. Queued invoices whose job may have been lost
  # are queued again as well; the delivery claim makes duplicates harmless.
  def resend_failed!
    requeued = invoices.reload.select(&:requeue!)
    stale = invoices.select { |invoice| invoice.queued? && invoice.updated_at < 10.minutes.ago }
    (requeued + stale).uniq.each { |invoice| ParticipationInvoiceDeliveryJob.perform_later(invoice.id) }
    (requeued + stale).uniq.size
  end

  def status_counts
    counts = invoices.unscope(:order).group(:status).count
    ParticipationInvoice.statuses.keys.index_with { |status| counts.fetch(status, 0) }
  end

  def total_cents
    invoices.sum(:amount_cents)
  end

  private

  def creditor_present
    errors.add(:base, "Die Bankverbindung fehlt.") if creditor.blank? || creditor["iban"].blank?
  end
end
