class Admin::PrintOrderExportsController < Admin::BaseController
  before_action :prepare_export
  before_action :prepare_label_layout, only: [ :addresses, :address_preview, :download_addresses ]
  rescue_from PrintOrderPdf::LayoutError, with: :layout_error

  def addresses
    valid_label_export?
  end

  def address_preview
    return render_export_errors unless valid_label_export?

    send_data PrintOrderPdf.new(@export).addresses(layout: @label_layout, guides: true), type: "application/pdf",
      disposition: "inline", filename: "adressen-vorschau-#{@year}.pdf"
  end

  def download_addresses
    return render_export_errors unless valid_label_export?

    send_data PrintOrderPdf.new(@export).addresses(layout: @label_layout), type: "application/pdf", filename: "adressen-#{@year}.pdf"
  end

  def letters
    @export.valid?
  end

  def preview
    return render_export_errors unless valid_export?
    # Only select from this year's printable orders, never by an unscoped ID.
    order = params[:order_id].present? ? @export.orders.find { |item| item.id.to_s == params[:order_id].to_s } : @export.orders.first
    raise ActiveRecord::RecordNotFound unless order
    send_data PrintOrderPdf.new(@export).letters(orders: [ order ]), type: "application/pdf",
      disposition: "inline", filename: "brief-vorschau-#{@year}.pdf"
  end

  def download
    return render_export_errors unless valid_export?
    pdf = PrintOrderPdf.new(@export)
    if params[:document_format] == "zip"
      send_data pdf.archive, type: "application/zip", filename: "briefe-#{@year}.zip"
    else
      send_data pdf.letters, type: "application/pdf", filename: "briefe-#{@year}.pdf"
    end
  end

  private

  def prepare_export
    @year = list_year
    @export = PrintOrderExport.new(year: @year, message: params.fetch(:message, PrintOrderExport::DEFAULT_MESSAGE))
    response.headers["Cache-Control"] = "no-store, private"
    response.headers["X-Robots-Tag"] = "noindex, nofollow"
  end

  def valid_export?
    @export.valid?
  end

  def prepare_label_layout
    @label_layout = PrintLabelLayout.new(params.fetch(:label_layout, ActionController::Parameters.new).permit(*PrintLabelLayout::FIELDS.keys).to_h)
  end

  def valid_label_export?
    @export.valid?
    unless @label_layout.valid?
      @label_layout.errors.full_messages.each { |message| @export.errors.add(:base, message) }
    end
    if @export.missing_addresses.any?
      @export.errors.add(:base, "Bitte ergänzen Sie zuerst die fehlenden Lieferadressen.")
    end
    @export.errors.empty?
  end

  def render_export_errors
    if %w[preview address_preview].include?(action_name)
      render :preview_error, formats: [ :html ], layout: false, status: :unprocessable_entity
    elsif action_name == "download_addresses"
      render :addresses, formats: [ :html ], status: :unprocessable_entity
    else
      render :letters, formats: [ :html ], status: :unprocessable_entity
    end
  end

  def layout_error(error)
    @export.errors.add(:base, error.message)
    render_export_errors
  end
end
