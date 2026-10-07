class BusinessExport
  SORT_OPTIONS = {
    "address_asc" => "Adresse A–Z",
    "name_asc" => "Geschäftsname A–Z"
  }.freeze
  DEFAULT_SORT = "address_asc"

  STATUS_LABELS = {
    "pending" => "Ausstehend",
    "confirmed" => "Bestätigt",
    "rejected" => "Abgelehnt",
    "deleted" => "Archiviert"
  }.freeze

  HEADERS = [
    "Geschäft", "Adresse", "Kategorien", "Status", "Kontaktperson", "Telefon",
    "Geschäftliche E-Mail", "Konto-E-Mail", "Rechnungsadresse", "Website"
  ].freeze

  attr_reader :sort, :status

  def initialize(sort: nil, status: nil)
    @sort = SORT_OPTIONS.key?(sort.to_s) ? sort.to_s : DEFAULT_SORT
    @status = STATUS_LABELS.key?(status.to_s) ? status.to_s : nil
  end

  def businesses
    @businesses ||= begin
      scope = Business.includes(:user)
      scope = scope.where(status: status) if status
      scope.reorder(*order_values).to_a
    end
  end

  def rows
    @rows ||= businesses.map do |business|
      [
        business.business_name,
        business.address,
        Array(business.categories).compact_blank.join(", "),
        STATUS_LABELS.fetch(business.status, "Unbekannt"),
        business.contact_name,
        business.phone,
        business.email,
        business.user.email,
        business.billing_address,
        business.website
      ].map { |value| value.to_s }
    end
  end

  def to_xlsx
    package = Axlsx::Package.new
    workbook = package.workbook
    header_style = workbook.styles.add_style(
      bg_color: "1F2937", fg_color: "FFFFFF", b: true, alignment: { vertical: :center }
    )
    cell_style = workbook.styles.add_style(alignment: { vertical: :top, wrap_text: true })

    workbook.add_worksheet(name: "Geschäfte") do |sheet|
      sheet.add_row HEADERS, style: header_style, types: Array.new(HEADERS.size, :string)
      rows.each do |row|
        sheet.add_row row, style: cell_style, types: Array.new(HEADERS.size, :string)
      end
      sheet.auto_filter = "A1:J#{rows.size + 1}"
      sheet.sheet_view.pane do |pane|
        pane.top_left_cell = "A2"
        pane.state = :frozen
        pane.y_split = 1
        pane.active_pane = :bottom_left
      end
      sheet.column_widths 28, 30, 24, 15, 24, 18, 30, 30, 30, 28
    end

    package.to_stream.read
  end

  private

  def order_values
    if sort == "name_asc"
      [ Arel.sql("LOWER(businesses.business_name) ASC"), Arel.sql("LOWER(businesses.address) ASC"), :id ]
    else
      [ Arel.sql("LOWER(businesses.address) ASC"), Arel.sql("LOWER(businesses.business_name) ASC"), :id ]
    end
  end
end
