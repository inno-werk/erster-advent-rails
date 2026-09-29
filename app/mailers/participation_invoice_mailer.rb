# Invoices go out as a plain-text email without the branded layout; the
# design lives in the attached PDF.
class ParticipationInvoiceMailer < ApplicationMailer
  class DeliveryDisabled < StandardError; end

  layout false

  # Raise instead of silently skipping, so a job never records a skipped
  # message as sent.
  before_deliver { raise DeliveryDisabled, "E-Mail-Versand ist deaktiviert (PROD_SEND ist nicht true)." unless EmailDelivery.enabled? }

  def invoice(invoice, pdf)
    @invoice = invoice
    @run = invoice.invoice_run
    attachments[invoice.filename] = { mime_type: "application/pdf", content: pdf }
    mail(to: invoice.recipient_email, subject: @run.subject)
  end
end
