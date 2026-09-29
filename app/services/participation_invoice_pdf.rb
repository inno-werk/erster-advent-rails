require "prawn"

# Renders a participation invoice exactly like docs/QR_Rechnung_A_haarglanz.pdf:
# page 1 is the letter, page 2 the Swiss QR-bill payment part.
#
# Coordinates are measured from the reference PDF, in points from the top of
# the A4 page, and refer to text baselines. Carlito is metrically identical to
# Calibri and Liberation Sans to Arial (both SIL OFL, see vendor/fonts).
class ParticipationInvoicePdf
  class LayoutError < StandardError; end

  PAGE_HEIGHT = 841.89
  COPPER = "B37E5C"
  BLACK = "000000"
  FONT_DIR = Rails.root.join("vendor/fonts")
  MM = 72 / 25.4

  # Table rules and columns of the position table.
  TABLE_LEFT = 93.12
  TABLE_RIGHT = 522.0
  COLUMNS = [ 98.17, 194.17, 290.17, 386.17, 482.17 ].freeze
  TABLE_TOP = 382.56
  TEXT_X = 93.67
  TEXT_WIDTH = 421.5
  BOTTOM_LIMIT = 800

  def initialize(invoice)
    @invoice = invoice
    @run = invoice.invoice_run
    @creditor = @run.creditor.to_h.transform_keys(&:to_s)
  end

  def render
    qr_bill = SwissQrBill.new(creditor: @creditor, amount_cents: @invoice.amount_cents, message: @invoice.payment_message)
    pdf = Prawn::Document.new(page_size: "A4", margin: 0,
      info: { Title: "Rechnung Teilnahmebeitrag #{@invoice.year}", Author: @creditor["creditor_name"].to_s, Creator: "Erster Advent Bern" })
    pdf.font_families.update(
      "Carlito" => { normal: font("Carlito-Regular.ttf"), bold: font("Carlito-Bold.ttf"), italic: font("Carlito-Italic.ttf") },
      "Liberation" => { normal: font("LiberationSans-Regular.ttf"), bold: font("LiberationSans-Bold.ttf") }
    )
    letter(pdf)
    pdf.start_new_page
    payment_part(pdf, qr_bill)
    pdf.render
  end

  private

  def font(name)
    FONT_DIR.join(name).to_s
  end

  def invoice_date
    (@run.created_at || Time.current).in_time_zone.to_date
  end

  # --- Page 1 --------------------------------------------------------------

  def letter(pdf)
    letterhead = @creditor["letterhead"].to_s.lines.map(&:strip).reject(&:blank?)
    letterhead.each_with_index do |line, index|
      line(pdf, line.upcase, x: 36.66, baseline: 42.48 + index * 11.617, size: 7.92, family: "Carlito", style: index.zero? ? :bold : :normal, color: COPPER)
    end

    line(pdf, @invoice.recipient_name.upcase, x: 36.66, baseline: 145.98, size: 7.92, family: "Carlito", style: :bold, color: COPPER)
    @invoice.recipient_address.to_s.lines.map(&:strip).reject(&:blank?).each_with_index do |address_line, index|
      line(pdf, address_line, x: 36.66, baseline: 157.96 + index * 11.98, size: 7.92, family: "Carlito", color: COPPER)
    end

    line(pdf, "Bern, #{I18n.l(invoice_date, format: "%-d. %B %Y", locale: :de)}", x: 94.37, baseline: 229.87, size: 7.92)
    line(pdf, "Erster Advent Untere Altstadt Bern", x: 94.42, baseline: 253.5, size: 13.92, style: :bold)
    line(pdf, "Rechnung Teilnahmebeitrag #{@invoice.year}", x: 94.42, baseline: 280.32, size: 13.92)

    last_baseline = paragraph(pdf, @run.message, x: TEXT_X, baseline: 320.05, width: TEXT_WIDTH, size: 9.12, leading: 11.0)
    table_bottom = position_table(pdf, top: [ TABLE_TOP, last_baseline + 40.5 ].max)
    closing(pdf, total_baseline: table_bottom)
  end

  # Returns the baseline of the «Betrag exkl. MwSt.» row.
  def position_table(pdf, top:)
    rule(pdf, top, width: 1)
    %w[Pos Betreff Menge Preis Total].each_with_index do |label, index|
      line(pdf, label, x: COLUMNS[index], baseline: top + 15.0, size: 9.12, style: :bold)
    end
    rule(pdf, top + 24.0, width: 1)

    title_lines = @invoice.position_title.lines.map(&:strip)
    [ "1.0", nil, "1", @invoice.amount, @invoice.amount ].each_with_index do |value, index|
      line(pdf, value, x: COLUMNS[index], baseline: top + 38.25, size: 9.12) if value
    end
    title_lines.each_with_index do |title, index|
      pdf.font("Liberation") { fits!(pdf, title, COLUMNS[2] - COLUMNS[1] - 4, 9.12) }
      line(pdf, title, x: COLUMNS[1], baseline: top + 38.25 + index * 11.25, size: 9.12)
    end
    extra = (title_lines.size - 2).clamp(0, 5) * 11.25

    rule(pdf, top + 58.44 + extra, width: 2)
    line(pdf, "Betrag exkl. MwSt.*", x: COLUMNS[0], baseline: top + 72.75 + extra, size: 9.12)
    line(pdf, @invoice.amount, x: COLUMNS[4], baseline: top + 72.75 + extra, size: 9.12, style: :bold)
    top + 72.75 + extra
  end

  def closing(pdf, total_baseline:)
    base = total_baseline
    line(pdf, "* Die oben aufgeführten Dienstleistungen sind gemäss Art. 10, Abs. 2, lit. a des Bundesgesetzes über die Mehrwertsteuer nicht",
      x: 92.92, baseline: base + 86.63, size: 7.44, family: "Carlito")
    line(pdf, "mehrwert-steuerpflichtig.", x: 92.92, baseline: base + 100.38, size: 7.44, family: "Carlito")

    line(pdf, "#{@creditor["bank_name"]} – #{InvoiceSetting.formatted_iban(@creditor["iban"])}", x: TEXT_X, baseline: base + 130.14, size: 7.92, family: "Carlito", style: :bold)
    line(pdf, [ @creditor["creditor_name"], street_line, postal_line ].join(" – "), x: TEXT_X, baseline: base + 143.98, size: 7.92, family: "Carlito")

    line(pdf, "Wir danken Ihnen für eine Zahlung innert 30 Tagen mittels obenstehender Bankverbindung. Bei Fragen oder",
      x: 92.92, baseline: base + 175.77, size: 9.12, family: "Carlito")
    lead = "Anregungen kontaktieren Sie uns gerne über die aufgeführten Kontaktangaben oder "
    line(pdf, lead, x: TEXT_X, baseline: base + 192.0, size: 9.12, family: "Carlito")
    lead_width = 0
    pdf.font("Carlito") { lead_width = pdf.width_of(lead, size: 9.12) }
    line(pdf, "Dir houet nis eifach ah uf dr Gass.", x: TEXT_X + lead_width, baseline: base + 192.0, size: 9.12, family: "Carlito", style: :italic)

    line(pdf, "Freundliche Grüsse", x: TEXT_X, baseline: base + 226.5, size: 9.12, family: "Carlito")
    greeting_baseline = base + 237.75
    raise LayoutError, "Der Text ist zu lang für eine Rechnungsseite. Bitte kürzen Sie ihn." if greeting_baseline > BOTTOM_LIMIT

    line(pdf, "Der Vorstand des Vereins «Erster Advent Untere Altstadt Bern»", x: TEXT_X, baseline: greeting_baseline, size: 9.12, family: "Carlito")
  end

  # --- Page 2: Swiss QR bill ------------------------------------------------

  def payment_part(pdf, qr_bill)
    separators(pdf)
    amount = qr_bill.amount
    account = [ InvoiceSetting.formatted_iban(@creditor["iban"]), @creditor["creditor_name"], street_line, postal_line ].compact_blank

    # Receipt
    slip(pdf, "Empfangsschein", x: 14.17, baseline: 578.27, size: 11)
    slip(pdf, "Konto/Zahlbar an", x: 14.17, baseline: 600.95, size: 6)
    account.each_with_index { |text, index| slip(pdf, text, x: 14.17, baseline: 610.58 + index * 6.8, size: 6) }
    slip(pdf, "Zahlbar durch (Name/Adresse)", x: 14.17, baseline: 643.47, size: 6)
    corner_marks(pdf, left: 14.32, top: 653.2, width: 147.6, height: 56.88, line_width: 0.75)
    slip(pdf, "Währung Betrag", x: 14.17, baseline: 751.18, size: 6)
    slip(pdf, "CHF", x: 14.17, baseline: 762.52, size: 6)
    slip(pdf, amount, x: 42.52, baseline: 762.52, size: 8)
    slip(pdf, "Annahmestelle", x: 99.21, baseline: 790.87, size: 6)

    # Payment part
    slip(pdf, "Zahlteil", x: 189.92, baseline: 578.27, size: 11)
    qr_code(pdf, qr_bill.qr_code, left: 190.04, top: 592.4, size: 46 * MM)
    slip(pdf, "Währung Betrag", x: 189.92, baseline: 751.18, size: 8)
    slip(pdf, "CHF", x: 189.92, baseline: 762.52, size: 8)
    slip(pdf, amount, x: 226.77, baseline: 762.52, size: 8)

    slip(pdf, "Konto/Zahlbar an", x: 334.49, baseline: 581.1, size: 8)
    account.each_with_index { |text, index| slip(pdf, text, x: 334.49, baseline: 593.01 + index * 11.34, size: 10) }
    slip(pdf, "Zusätzliche Informationen", x: 334.49, baseline: 646.87, size: 8)
    message_baseline = paragraph(pdf, @invoice.payment_message, x: 334.49, baseline: 658.77, width: 198.7, size: 10, leading: 11.34, family: "Liberation")
    debtor_heading = message_baseline + 19.85
    slip(pdf, "Zahlbar durch (Name/Adresse)", x: 334.49, baseline: debtor_heading, size: 8)
    corner_marks(pdf, left: 348.64, top: debtor_heading + 11.92, width: 184.56, height: 71.04, line_width: 1)
  end

  def separators(pdf)
    pdf.stroke_color BLACK
    pdf.line_width 0.75
    pdf.dash(3.24, space: 3.0)
    pdf.stroke_horizontal_line 0, pdf.bounds.width, at: y(543.0)
    pdf.stroke_vertical_line y(543.0), 0, at: 175.32
    pdf.undash
    scissors(pdf, x: 69.4, y: 543.0, rotate: 0)
    scissors(pdf, x: 175.32, y: 586.5, rotate: -90)
  end

  # Open scissors on the cutting lines: ring handles at the origin, blades
  # pointing along the line (to the right before rotation).
  def scissors(pdf, x:, y:, rotate:)
    base_x = x
    base_y = y(y)
    point = ->(dx, dy) { [ base_x + dx, base_y + dy ] }
    pdf.rotate(rotate, origin: [ base_x, base_y ]) do
      pdf.fill_color "FFFFFF"
      pdf.fill_rectangle point.(-1.5, 6.2), 28, 12.4
      pdf.fill_color BLACK
      pdf.stroke_color BLACK
      pdf.line_width 1.0
      pdf.stroke_circle point.(3.1, 3.5), 2.0
      pdf.stroke_circle point.(3.1, -3.7), 2.0
      pdf.fill_polygon point.(4.6, -2.2), point.(9.8, 0.9), point.(24.4, 4.9), point.(24.8, 3.8), point.(12.6, -1.3), point.(5.6, -4.1)
      pdf.fill_polygon point.(4.6, 2.1), point.(9.8, -0.9), point.(24.6, -4.2), point.(25.0, -3.1), point.(12.6, 1.3), point.(5.6, 4.0)
    end
  end

  def qr_code(pdf, qr, left:, top:, size:)
    modules = qr.qrcode.modules
    module_size = size / modules.size
    pdf.fill_color BLACK
    modules.each_with_index do |row, row_index|
      column = 0
      while column < row.size
        if row[column]
          start = column
          column += 1 while column < row.size && row[column]
          pdf.fill_rectangle [ left + start * module_size, y(top + row_index * module_size) ], (column - start) * module_size, module_size
        else
          column += 1
        end
      end
    end
    swiss_cross(pdf, center_x: left + size / 2, center_y: top + size / 2)
  end

  # Swiss cross (7 × 7 mm) in the centre of the QR code.
  def swiss_cross(pdf, center_x:, center_y:)
    outer = 7 * MM
    inner = 6 * MM
    arm_length = inner * 20 / 32
    arm_width = inner * 6 / 32
    pdf.fill_color "FFFFFF"
    pdf.fill_rectangle [ center_x - outer / 2, y(center_y - outer / 2) ], outer, outer
    pdf.fill_color BLACK
    pdf.fill_rectangle [ center_x - inner / 2, y(center_y - inner / 2) ], inner, inner
    pdf.fill_color "FFFFFF"
    pdf.fill_rectangle [ center_x - arm_width / 2, y(center_y - arm_length / 2) ], arm_width, arm_length
    pdf.fill_rectangle [ center_x - arm_length / 2, y(center_y - arm_width / 2) ], arm_length, arm_width
    pdf.fill_color BLACK
  end

  def corner_marks(pdf, left:, top:, width:, height:, line_width:)
    length = 3 * MM
    right = left + width
    bottom = top + height
    pdf.stroke_color BLACK
    pdf.line_width line_width
    inset = line_width / 2
    [
      [ [ left + inset, top + length ], [ left + inset, top + inset ], [ left + length, top + inset ] ],
      [ [ right - length, top + inset ], [ right - inset, top + inset ], [ right - inset, top + length ] ],
      [ [ left + inset, bottom - length ], [ left + inset, bottom - inset ], [ left + length, bottom - inset ] ],
      [ [ right - length, bottom - inset ], [ right - inset, bottom - inset ], [ right - inset, bottom - length ] ]
    ].each do |points|
      pdf.stroke { pdf.move_to(points[0][0], y(points[0][1])); points[1..].each { |px, py| pdf.line_to(px, y(py)) } }
    end
  end

  # --- Text helpers ---------------------------------------------------------

  def street_line
    [ @creditor["street"], @creditor["building_number"] ].compact_blank.join(" ")
  end

  def postal_line
    [ @creditor["postal_code"], @creditor["town"] ].compact_blank.join(" ")
  end

  def slip(pdf, text, **options)
    line(pdf, text, **options, family: "Liberation")
  end

  # Draws one line with its baseline at the given distance from the top.
  def line(pdf, text, x:, baseline:, size:, family: "Liberation", style: :normal, color: BLACK)
    pdf.font(family, style: style) do
      supported!(pdf, text)
      pdf.fill_color color
      pdf.draw_text text.to_s, at: [ x, y(baseline) ], size: size
    end
  end

  # Wraps text into the width, draws it line by line and returns the last baseline.
  def paragraph(pdf, text, x:, baseline:, width:, size:, leading:, family: "Liberation")
    lines = []
    pdf.font(family) do
      supported!(pdf, text)
      lines = text.to_s.gsub("\r\n", "\n").split("\n", -1).flat_map { |part| wrap(pdf, part, width, size) }
    end
    lines = lines.drop_while(&:blank?).reverse.drop_while(&:blank?).reverse
    lines.each_with_index { |text_line, index| line(pdf, text_line, x: x, baseline: baseline + index * leading, size: size, family: family) }
    baseline + [ lines.size - 1, 0 ].max * leading
  end

  def wrap(pdf, text, width, size)
    words = text.split(/ +/)
    return [ "" ] if words.empty?

    words.each_with_object([ +"" ]) do |word, lines|
      fits!(pdf, word, width, size)
      candidate = lines.last.empty? ? word : "#{lines.last} #{word}"
      if pdf.width_of(candidate, size: size) <= width
        lines[-1] = candidate
      else
        lines << word.dup
      end
    end
  end

  def fits!(pdf, text, width, size)
    raise LayoutError, "Das Wort «#{text.truncate(40)}» ist zu lang für die Rechnung." if pdf.width_of(text, size: size) > width
  end

  def supported!(pdf, text)
    unsupported = text.to_s.each_char.reject { |char| char.match?(/\s/) || pdf.font.glyph_present?(char) }.uniq
    return if unsupported.empty?

    raise LayoutError, "Die Rechnungsschrift unterstützt folgende Zeichen nicht: #{unsupported.join(' ')}. Bitte ersetzen Sie diese im Text."
  end

  def rule(pdf, top, width:)
    pdf.stroke_color BLACK
    pdf.line_width width
    pdf.stroke_horizontal_line TABLE_LEFT, TABLE_RIGHT, at: y(top)
  end

  def y(from_top)
    PAGE_HEIGHT - from_top
  end
end
