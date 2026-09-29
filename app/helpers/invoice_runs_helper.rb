module InvoiceRunsHelper
  INVOICE_STATUS_LABELS = {
    "queued" => [ "Wartet", "badge-ghost" ],
    "sending" => [ "Wird gesendet", "badge-info" ],
    "sent" => [ "Versendet", "badge-success" ],
    "failed" => [ "Fehlgeschlagen", "badge-error" ],
    "cancelled" => [ "Nicht versendet", "badge-warning" ]
  }.freeze

  def invoice_chf(cents)
    format("CHF %d.%02d", cents / 100, cents % 100)
  end

  def invoice_status_badge(invoice)
    label, css = INVOICE_STATUS_LABELS.fetch(invoice.status)
    # An invoice left in «sending» for long was interrupted during SMTP delivery.
    label = "Unklar – bitte prüfen" if invoice.sending? && invoice.updated_at < 30.minutes.ago
    tag.span(label, class: "badge badge-sm whitespace-nowrap #{css}")
  end

  def invoice_category_label(category, previous_category = nil)
    code = ParticipationInvoice::CATEGORY_CODES.fetch(category)
    title = Participation::CATEGORIES.dig(category, :title)
    return "Kat. #{code} – #{title}" unless previous_category

    "Differenz Kat. #{ParticipationInvoice::CATEGORY_CODES.fetch(previous_category)} → #{code} – #{title}"
  end
end
