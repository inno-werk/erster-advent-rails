require "prawn"
require "prawn-svg"
require "zip"

class PrintOrderPdf
  class LayoutError < StandardError; end

  INK = "243B36"
  MUTED = "66736E"
  RULE = "DDE4DF"
  LETTER_INK = "202424"
  ACCENT = "D03036"

  def initialize(export)
    @export = export
  end

  def addresses(layout: PrintLabelLayout.new, guides: false)
    raise LayoutError, layout.errors.full_messages.join(" ") unless layout.valid?

    pdf = document(margin: 0)
    mm = 72.0 / 25.4
    width = layout.label_width * mm
    height = layout.label_height * mm
    padding_x = layout.padding_horizontal.to_f * mm
    padding_y = layout.padding_vertical.to_f * mm
    draw_label_guides(pdf, layout, mm) if guides
    @export.orders.each_with_index do |order, index|
      if index.positive? && (index % layout.per_page).zero?
        pdf.start_new_page
        draw_label_guides(pdf, layout, mm) if guides
      end
      slot = index % layout.per_page
      column = slot % layout.columns.to_i
      row = slot / layout.columns.to_i
      x = layout.margin_left.to_f * mm + column * (width + layout.gap_horizontal.to_f * mm)
      y = pdf.bounds.top - layout.margin_top.to_f * mm - row * (height + layout.gap_vertical.to_f * mm)
      box(pdf, @export.recipient(order), at: [ x + padding_x, y - padding_y ],
        width: width - 2 * padding_x, height: height - 2 * padding_y, size: layout.font_size.to_f, min_font_size: 8)
    end
    pdf.render
  end

  def letters(orders: @export.orders)
    pdf = document
    orders.each_with_index do |order, index|
      pdf.start_new_page if index.positive?
      letter(pdf, order)
    end
    pdf.render
  end

  def archive
    Zip::OutputStream.write_buffer do |zip|
      @export.orders.each do |order|
        name = @export.store_name(order).parameterize.presence || "geschaeft"
        zip.put_next_entry("#{@export.year}-#{name.first(80)}-#{order.id}.pdf")
        zip.write(letters(orders: [ order ]))
      end
    end.string
  end

  private

  def draw_label_guides(pdf, layout, mm)
    pdf.stroke_color RULE
    pdf.line_width 0.4
    layout.rows.to_i.times do |row|
      layout.columns.to_i.times do |column|
        x = layout.margin_left.to_f + column * (layout.label_width + layout.gap_horizontal.to_f)
        y = layout.margin_top.to_f + row * (layout.label_height + layout.gap_vertical.to_f)
        pdf.stroke_rectangle([ x * mm, pdf.bounds.top - y * mm ], layout.label_width * mm, layout.label_height * mm)
      end
    end
  end

  def document(margin: 48)
    pdf = Prawn::Document.new(page_size: "A4", margin: margin,
      info: { Title: "Printbestellungen #{@export.year}", Author: "Erster Advent Untere Altstadt Bern" })
    pdf.font_families.update("Jakarta" => { normal: Rails.root.join("app/assets/fonts/PlusJakartaSans.ttf").to_s })
    pdf.font("Jakarta")
    pdf.fill_color INK
    pdf
  end

  def letter(pdf, order)
    width = pdf.bounds.width
    top = pdf.bounds.top
    pdf.svg(Rails.root.join("app/assets/images/logo.svg").read, at: [ 0, top ], height: 52, enable_web_requests: false)
    box(pdf, "ERSTER ADVENT", at: [ 58, top - 9 ], width: 275, height: 20, size: 12, character_spacing: 1, color: LETTER_INK)
    box(pdf, "Untere Altstadt Bern", at: [ 58, top - 32 ], width: 275, height: 18, size: 10, color: MUTED)
    box(pdf, @export.year.to_s, at: [ width - 100, top - 4 ], width: 100, height: 42, size: 32, align: :right, color: ACCENT)
    rule(pdf, top - 77)

    box(pdf, "BESTELLUNG / ##{order.id}", at: [ 0, top - 101 ], width: width, height: 18, size: 8, character_spacing: 1.1, color: MUTED)
    box(pdf, "Ihre Printbestellung", at: [ 0, top - 123 ], width: width, height: 44, size: 29, character_spacing: -0.5, color: LETTER_INK)

    box(pdf, "LIEFERADRESSE", at: [ 0, top - 186 ], width: 260, height: 18, size: 8, character_spacing: 0.8, color: MUTED)
    box(pdf, @export.recipient(order), at: [ 0, top - 207 ], width: 260, height: 78, size: 11, color: LETTER_INK)
    box(pdf, "KONTAKT & VERTEILUNG", at: [ 284, top - 186 ], width: width - 284, height: 18, size: 8, character_spacing: 0.8, color: MUTED)
    info = @export.contact(order)
    info += "\n\nVerteildatum: #{I18n.l(@export.distribution_on)}" if @export.distribution_on
    box(pdf, info, at: [ 284, top - 207 ], width: width - 284, height: 78, size: 10, color: LETTER_INK)

    message_top = top - 309
    table_top = message_top
    if @export.message.present?
      message_height = pdf.height_of(@export.message, width: width, size: 10.5, leading: 4)
      table_top -= message_height + 30
    end
    # Validate the available table space before drawing the message. Very tall
    # text must be rejected, not allowed to spill across the footer or a page.
    order_table(pdf, order, top: table_top, bottom: 65)
    if @export.message.present?
      box(pdf, @export.message, at: [ 0, message_top ], width: width, height: message_height + 2, size: 10.5, leading: 4, color: LETTER_INK)
    end

    pdf.stroke_color ACCENT
    pdf.line_width 2
    pdf.stroke_horizontal_line 0, 28, at: 35
    box(pdf, "ERSTER ADVENT", at: [ 0, 23 ], width: 150, height: 20, size: 7.5, character_spacing: 0.8, color: LETTER_INK)
    box(pdf, "Untere Altstadt Bern", at: [ 150, 23 ], width: width - 230, height: 20, size: 8, color: MUTED)
    box(pdf, "#{@export.year} / 1", at: [ width - 80, 23 ], width: 80, height: 20, size: 8, align: :right, color: MUTED)
  end

  def order_table(pdf, order, top:, bottom:)
    width = pdf.bounds.width
    items = order.items.sort_by { |item| [ item.print_product.position, item.print_product_id ] }
    # Keep every item on one page. Refuse oversized content rather than clip it.
    size = [ 11, 10, 9 ].find do |candidate|
      items.sum { |item| row_height(pdf, item, candidate) } + 34 <= top - bottom
    end
    raise LayoutError, "Die Bestellung für #{@export.store_name(order)} passt nicht auf eine Seite. Bitte kürzen Sie die Mitteilung oder die Produktbezeichnungen." unless size

    pdf.stroke_color LETTER_INK
    pdf.line_width 1
    pdf.stroke_horizontal_line 0, width, at: top
    box(pdf, "PRINTMATERIAL / BÜNDEL", at: [ 0, top - 11 ], width: width - 125, height: 18, size: 8, character_spacing: 0.8, color: MUTED)
    box(pdf, "ANZAHL", at: [ width - 95, top - 11 ], width: 95, height: 18, size: 8, character_spacing: 0.8, align: :right, color: MUTED)
    y = top - 34
    items.each_with_index do |item, index|
      height = row_height(pdf, item, size)
      box(pdf, format("%02d", index + 1), at: [ 0, y - 11 ], width: 25, height: height - 16, size: 8, color: MUTED)
      box(pdf, item.print_product.title, at: [ 32, y - 8 ], width: width - 145, height: height - 16, size: size, color: LETTER_INK)
      box(pdf, "#{item.quantity} Bündel", at: [ width - 105, y - 8 ], width: 105, height: height - 16, size: size, align: :right, color: LETTER_INK)
      rule(pdf, y - height)
      y -= height
    end
  end

  def row_height(pdf, item, size)
    [ pdf.height_of(item.print_product.title, width: pdf.bounds.width - 145, size: size), size + 4 ].max + 24
  end

  def rule(pdf, y)
    pdf.stroke_color RULE
    pdf.line_width 0.6
    pdf.stroke_horizontal_line 0, pdf.bounds.width, at: y
  end

  def box(pdf, text, color: INK, **options)
    pdf.fill_color color
    unsupported = text.to_s.each_char.reject { |char| char.match?(/\s/) || pdf.font.glyph_present?(char) }.uniq
    if unsupported.any?
      raise LayoutError, "Die Druckschrift unterstützt folgende Zeichen nicht: #{unsupported.join(' ')}. Bitte ersetzen Sie diese im Text."
    end
    remaining = pdf.text_box(text.to_s, **{ overflow: :shrink_to_fit, min_font_size: 9 }.merge(options))
    raise LayoutError, "Ein Text ist zu lang für das Druckformat. Bitte kürzen Sie die Adresse, Produktbezeichnung oder Mitteilung." if remaining.present?
  end
end
