# Sends one participation invoice. The invoice is claimed under a row lock
# (queued → sending) after re-checking PROD_SEND and the open amount, so a
# duplicate or repeated job never emails the same invoice twice.
#
# Failures are recorded on the invoice instead of being retried
# automatically: an administrator resends failed invoices explicitly. An
# invoice interrupted during SMTP delivery stays «sending» and is never resent
# automatically, because the email may already have been delivered.
class ParticipationInvoiceDeliveryJob < ApplicationJob
  queue_as :default

  def perform(invoice_id)
    invoice = ParticipationInvoice.find_by(id: invoice_id)
    return unless invoice&.claim_for_delivery!

    begin
      pdf = ParticipationInvoicePdf.new(invoice).render
      ParticipationInvoiceMailer.invoice(invoice, pdf).deliver_now
    rescue StandardError => error
      Rails.logger.warn("[ParticipationInvoiceDeliveryJob] invoice=#{invoice.id} failed: #{error.class}")
      invoice.mark_failed!(error)
      return
    end
    invoice.mark_sent!
  end
end
