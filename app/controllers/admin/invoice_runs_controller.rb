# Emails participation invoices with a Swiss QR bill to every member with an
# open amount in the active event year. Recipients and amounts are always
# computed on the server. Subject and text are saved per year (InvoiceText);
# a run only sends the saved text the admin reviewed.
class Admin::InvoiceRunsController < Admin::BaseController
  before_action :prevent_caching

  def new
    prepare_form(editing_text: params[:edit_text] == "1")
  end

  # Saves subject and text for the active year (edit mode of step 2).
  def text
    invoice_text = InvoiceText.find_or_initialize_by(year: year)
    invoice_text.assign_attributes(params.require(:invoice_text).permit(:subject, :message).merge(updated_by: current_user))
    if invoice_text.save
      redirect_to new_admin_invoice_run_path(anchor: "step-2"), notice: "Betreff und Text wurden gespeichert.", status: :see_other
    else
      prepare_form(text_form: invoice_text)
      render :new, status: :unprocessable_entity
    end
  end

  def create
    raise InvoiceRun::Refused, "Bitte bestätigen Sie, dass Sie Liste und Vorschau geprüft haben." unless params[:confirmed] == "1"
    unless InvoiceText.for_year(year).matches?(params[:subject], params[:message])
      raise InvoiceRun::Refused, "Betreff oder Text wurden inzwischen geändert. Bitte prüfen Sie den aktuellen Text und die Vorschau erneut."
    end

    run = InvoiceRun.start!(year: year, subject: params[:subject], message: params[:message],
      idempotency_key: params[:idempotency_key], recipients_digest: params[:recipients_digest], created_by: current_user)
    redirect_to admin_invoice_run_path(run), notice: "#{run.invoices.size} Rechnungen wurden zum Versand eingereiht.", status: :see_other
  rescue InvoiceRun::Refused => error
    prepare_form(idempotency_key: params[:idempotency_key])
    flash.now[:alert] = error.message
    render :new, status: :unprocessable_entity
  end

  def preview
    recipients = ParticipationInvoice.recipients(year)
    # Only preview members of this year's recipient list, never by an unscoped ID.
    recipient = params[:participation_id].present? ? recipients.find { |item| item.participation.id.to_s == params[:participation_id].to_s } : recipients.first
    setting = InvoiceSetting.current
    @errors = []
    @errors << "Keine offene Zahlung für die Vorschau gefunden." unless recipient
    @errors << "Die Bankverbindung ist unvollständig: #{setting.errors.full_messages.to_sentence}" unless setting.valid?
    @errors << recipient.problem if recipient&.problem
    return render(:preview_error, layout: false, status: :unprocessable_entity) if @errors.any?

    saved_text = InvoiceText.for_year(year)
    run = InvoiceRun.new(year: year, subject: params[:subject].presence || saved_text.subject,
      message: params[:message].presence || saved_text.message, creditor: setting.snapshot,
      idempotency_key: "preview-#{SecureRandom.uuid}", created_at: Time.current)
    unless run.valid?
      @errors = run.errors.full_messages
      return render(:preview_error, layout: false, status: :unprocessable_entity)
    end
    invoice = ParticipationInvoice.build_for(recipient, run)
    send_data ParticipationInvoicePdf.new(invoice).render, type: "application/pdf", disposition: "inline",
      filename: "vorschau-#{invoice.filename}"
  rescue ParticipationInvoicePdf::LayoutError, SwissQrBill::InvalidData => error
    @errors = [ error.message ]
    render :preview_error, layout: false, status: :unprocessable_entity
  end

  def show
    @run = InvoiceRun.find(params[:id])
    @invoices = @run.invoices.to_a
    @counts = @run.status_counts
  end

  def resend
    run = InvoiceRun.find(params[:id])
    unless EmailDelivery.enabled?
      redirect_to admin_invoice_run_path(run), alert: "Der E-Mail-Versand ist deaktiviert (PROD_SEND ist nicht true).", status: :see_other
      return
    end
    count = run.resend_failed!
    redirect_to admin_invoice_run_path(run), notice: "#{count} Rechnungen wurden erneut zum Versand eingereiht.", status: :see_other
  end

  private

  # Invoices are only sent for the active event year.
  def year
    EventConfiguration.year
  end

  # text_form: an InvoiceText with validation errors, shown in edit mode.
  def prepare_form(editing_text: false, text_form: nil, idempotency_key: nil)
    @year = year
    # Shown, previewed and sent is always the saved text (or the default).
    @invoice_text = InvoiceText.for_year(@year)
    @text_form = text_form || @invoice_text
    @editing_text = editing_text || text_form.present?
    @idempotency_key = idempotency_key.presence || SecureRandom.uuid
    @recipients = ParticipationInvoice.recipients(@year)
    @recipients_digest = ParticipationInvoice.recipients_digest(@recipients)
    @last_sent_at = ParticipationInvoice.last_sent_at_by_participation(@recipients.map { |recipient| recipient.participation.id })
    @problems = @recipients.select(&:problem)
    @setting = InvoiceSetting.current
    @setting_ready = @setting.persisted? && @setting.valid?
    @delivery_enabled = EmailDelivery.enabled?
    @in_progress = InvoiceRun.in_progress?(@year)
    @runs = InvoiceRun.where(year: @year).includes(:created_by).order(created_at: :desc).limit(10).to_a
    @run_counts = ParticipationInvoice.where(invoice_run_id: @runs.map(&:id)).group(:invoice_run_id, :status).count
  end

  def prevent_caching
    response.headers["Cache-Control"] = "no-store, private"
    response.headers["X-Robots-Tag"] = "noindex, nofollow"
  end
end
