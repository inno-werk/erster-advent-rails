require "test_helper"
require "pdf/reader"
require "zip"

class AdminPrintOrderExportsTest < ActionDispatch::IntegrationTest
  setup do
    @year = EventConfiguration.year
    @member_order = order_for(users(:member), print_products(:posters), 2)
    @other_order = order_for(users(:other), print_products(:postcards), 3)
    @old_order = order_for(users(:admin), print_products(:posters), 8, year: @year - 1)
    users(:admin).print_orders.create!(year: @year)
    sign_in users(:admin)
  end

  test "summary is a product quantity table above the list and print menu has exactly two choices" do
    get admin_print_orders_path, params: { q: "no match" }
    assert_response :success
    assert_select ".admin-list-empty"
    assert_select ".admin-list-header .admin-order-summary" do
      assert_select "h2", text: "Gesamtmengen #{@year}"
      assert_select "thead th[scope=col]", text: "Produkt"
      assert_select "thead th[scope=col]", text: "Anzahl"
      assert_select "tbody tr", count: 2
      assert_select "tbody th[scope=row]", text: print_products(:posters).title
      assert_select "strong", text: "2 Bündel"
      assert_select "strong", text: "3 Bündel"
      assert_select "strong", text: "8 Bündel", count: 0
    end
    assert_select ".admin-list-header .admin-list-overview" do
      assert_select ".admin-list-overview-actions [aria-label=Druckauswahl]"
    end
    assert_select ".admin-list-header .admin-list-overview + .admin-list-controls form.admin-list-toolbar"
    assert_select ".admin-list-scroll .admin-orders-section h2", text: "Alle Bestellungen"
    assert_select ".admin-list-footer .admin-order-summary, .admin-list-footer + .admin-order-summary", count: 0
    assert_select "[aria-label=Druckauswahl] a", count: 2
    assert_select "a[href=?]", addresses_admin_print_order_export_path(year: @year)
    assert_select "a[href=?]", letters_admin_print_order_export_path(year: @year)
    assert_select "aside a[href=?]", admin_emails_path, count: 0
  end

  test "all export endpoints require an admin including direct downloads" do
    [ users(:member), nil ].each do |user|
      sign_out :user
      sign_in user if user
      [ addresses_admin_print_order_export_path, address_preview_admin_print_order_export_path, letters_admin_print_order_export_path, preview_admin_print_order_export_path ].each do |path|
        get path
        assert_redirected_to root_path
      end
      [ preview_admin_print_order_export_path, download_admin_print_order_export_path, address_preview_admin_print_order_export_path, download_addresses_admin_print_order_export_path ].each do |path|
        post path, params: { document_format: "zip" }
        assert_redirected_to root_path
      end
    end
  end

  test "address export uses delivery addresses from the whole year even for unpaid stores" do
    businesses(:member).update!(billing_address: "SECRET BILLING ADDRESS", contact_name: "Müller & Söhne")
    post download_addresses_admin_print_order_export_path, params: { year: @year, q: "no match", page: 99, contents: "empty" }
    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_includes response.headers["Content-Disposition"], "attachment"
    assert_includes response.headers["Cache-Control"], "no-store"
    text = pdf.pages.sole.text
    assert_pdf_includes text, "Testgeschäft"
    assert_pdf_includes text, "Anderes Geschäft"
    assert_pdf_includes text, "Müller & Söhne"
    assert_pdf_includes text, "Kramgasse 1"
    assert_pdf_not_includes text, "SECRET BILLING ADDRESS"
    assert_not_includes text, "admin@example.com"
  end

  test "address labels paginate at sixteen in an A4 two by eight grid" do
    15.times do |index|
      user = User.create!(email: "labels-#{index}@example.com", password: "password123", business_name: "Laden #{index.to_s.rjust(2, '0')}", address: "Gasse #{index}\n3011 Bern")
      order_for(user, print_products(:posters), 1)
    end
    post download_addresses_admin_print_order_export_path
    assert_response :success
    document = pdf
    assert_equal 2, document.page_count
    assert_equal [ 0, 0, 595.28, 841.89 ], document.pages.first.attributes[:MediaBox]
    assert_equal 15, document.pages.first.text.scan(/Laden\s*\d{2}/).size
    assert_pdf_includes document.pages.first.text, "Anderes Geschäft"
    assert_includes document.pages.last.text, "Testgeschäft"
    assert_not_includes document.pages.last.text, "Laden"
    labels = document.pages.first.runs.select { |run| run.text.match?(/Laden|Anderes/) }
    assert_equal 2, labels.map { |run| run.x.round }.uniq.size
    assert_equal 8, labels.map { |run| run.y.round }.uniq.size

    custom = { columns: 3, rows: 4, margin_top: 11, margin_bottom: 13, margin_left: 10, margin_right: 14,
      gap_horizontal: 3, gap_vertical: 5, padding_horizontal: 2, padding_vertical: 3, font_size: 10 }
    post download_addresses_admin_print_order_export_path, params: { label_layout: custom }
    assert_response :success
    custom_document = pdf
    assert_equal 2, custom_document.page_count
    custom_labels = custom_document.pages.first.runs.select { |run| run.text.match?(/Laden|Anderes/) }
    assert_equal 12, custom_labels.size
    xs = custom_labels.map { |run| run.x.round(2) }.uniq.sort
    ys = custom_labels.map { |run| run.y.round(2) }.uniq.sort.reverse
    assert_equal 3, xs.size
    assert_equal 4, ys.size
    assert_in_delta 12 * 72.0 / 25.4, xs.first, 0.02
    assert_in_delta 63 * 72.0 / 25.4, xs[1] - xs[0], 0.02
    assert_in_delta 69.5 * 72.0 / 25.4, ys[0] - ys[1], 0.02

    @member_order.destroy!
    post download_addresses_admin_print_order_export_path
    assert_equal 1, pdf.page_count, "Exactly sixteen addresses must not create a blank page"
  end

  test "letters page offers an actual PDF preview and editable shared message" do
    get letters_admin_print_order_export_path, params: { year: @year }
    assert_response :success
    assert_select "textarea[name=message][maxlength='1000']", text: PrintOrderExport::DEFAULT_MESSAGE
    assert_select "select[name=order_id] option", count: 2
    assert_select "iframe[name=letter-preview][src=?]", preview_admin_print_order_export_path(year: @year)
    assert_select "button[form=print-letter-form][value=zip]"
    assert_select "button[form=print-letter-form][value=pdf]"
  end

  test "preview has only the selected store and current text while download includes every store" do
    message = "Liebe Geschäfte,\nGrüsse aus Bern! Wir freuen uns auf Sie."
    PrintDistribution.create!(year: @year, distribution_on: Date.new(@year, 11, 15))
    post preview_admin_print_order_export_path, params: { year: @year, order_id: @member_order.id, message: message }
    assert_response :success
    assert_includes response.headers["Content-Disposition"], "inline"
    preview_text = pdf.pages.sole.text
    assert_includes preview_text, "Testgeschäft"
    assert_pdf_includes preview_text, print_products(:posters).title
    assert_pdf_includes preview_text, "2 Bündel"
    assert_pdf_includes preview_text, "Grüsse aus Bern!"
    assert_includes preview_text, "15.11.#{@year}"
    assert_pdf_not_includes preview_text, "Anderes Geschäft"
    assert_pdf_not_includes preview_text, print_products(:postcards).title
    assert_pdf_not_includes preview_text.upcase, "PERSÖNLICHE MITTEILUNG"
    page = pdf.pages.sole
    message_line = page.runs.find { |run| run.text.gsub(/\s/, "").include?("GrüsseausBern!") }
    quantity_heading = page.runs.find { |run| run.text.gsub(/\s/, "") == "ANZAHL" }
    assert_operator message_line.y, :>, quantity_heading.y, "The introduction must appear above the quantities"
    assert_vector_logo(page)

    post download_admin_print_order_export_path, params: { year: @year, order_id: @member_order.id, message: message, document_format: "pdf" }
    assert_response :success
    document = pdf
    assert_equal 2, document.page_count
    assert_pdf_includes document.pages.first.text, "Anderes Geschäft"
    assert_equal preview_text, document.pages.last.text
    document.pages.each do |page|
      assert_pdf_includes page.text, "Grüsse aus Bern!"
      assert_vector_logo(page)
    end
  end

  test "zip contains one uniquely named one page PDF per order with the shared message" do
    businesses(:member).update!(business_name: "Same / Store")
    businesses(:other).update!(business_name: "Same / Store")
    post download_admin_print_order_export_path, params: { year: @year, message: "Gemeinsamer Text", document_format: "zip" }
    assert_response :success
    assert_equal "application/zip", response.media_type
    entries = []
    Zip::InputStream.open(StringIO.new(response.body)) do |zip|
      while (entry = zip.get_next_entry)
        entries << entry.name
        assert_match(/\A#{@year}-same-store-\d+\.pdf\z/, entry.name)
        document = PDF::Reader.new(StringIO.new(zip.read))
        assert_equal 1, document.page_count
        assert_pdf_includes document.pages.sole.text, "Gemeinsamer Text"
      end
    end
    assert_equal 2, entries.uniq.size
  end

  test "a preview cannot load an order from another year and year filters apply to downloads" do
    post download_admin_print_order_export_path, params: { year: @year - 1, message: "" }
    assert_response :success
    assert_equal 1, pdf.page_count
    assert_pdf_includes pdf.pages.first.text, "8 Bündel"
    assert_not_includes pdf.pages.first.text, "Testgeschäft"
    get preview_admin_print_order_export_path, params: { year: @year, order_id: @old_order.id }
    assert_response :not_found
  end

  test "empty years and oversized messages return helpful errors instead of empty or overflowing PDFs" do
    post download_addresses_admin_print_order_export_path, params: { year: @year - 2 }
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /keine Bestellungen/
    assert_select "button[form=print-label-form][disabled]"
    post download_admin_print_order_export_path, params: { message: "a" * 1001 }
    assert_response :unprocessable_entity
    assert_equal "text/html", response.media_type
    assert_select "[role=alert]", text: /1000 Zeichen/
    post preview_admin_print_order_export_path, params: { message: "a" * 1001 }
    assert_response :unprocessable_entity
    assert_select "h1", text: "Vorschau konnte nicht erstellt werden"
    assert_select ".admin-shell", count: 0
  end

  test "missing addresses block labels and are explained without excluding the order" do
    businesses(:other).update_column(:address, "")
    post download_addresses_admin_print_order_export_path
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /fehlenden Lieferadressen/
    assert_select "a[href=?]", edit_admin_store_path(businesses(:other)), text: "Anderes Geschäft"
    post download_admin_print_order_export_path, params: { message: "" }
    assert_response :success
    assert_equal 2, pdf.page_count
  end

  test "form supports both endpoints with CSRF protection enabled" do
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    get letters_admin_print_order_export_path
    token = css_select("#print-letter-form input[name=authenticity_token]").sole["value"]
    [ preview_admin_print_order_export_path, download_admin_print_order_export_path ].each do |path|
      post path, params: { authenticity_token: token, message: "Danke!" }
      assert_response :success
      assert_equal "application/pdf", response.media_type
    end
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  test "maximum length message and inactive products are printed in full on one page" do
    @member_order.items.create!(print_product: print_products(:inactive), quantity: 7)
    message = "Danke! " * 142 + "ENDE!!"
    assert_equal 1000, message.length
    post preview_admin_print_order_export_path, params: { order_id: @member_order.id, message: message }
    assert_response :success
    text = pdf.pages.sole.text
    assert_pdf_includes text, message
    assert_pdf_includes text, print_products(:inactive).title
    assert_pdf_includes text, "7 Bündel"
  end

  test "oversized addresses and unsupported characters are reported instead of clipped or replaced" do
    businesses(:member).update!(address: "Lange Adresse " * 300)
    post download_addresses_admin_print_order_export_path
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /zu lang für das Druckformat/
    post preview_admin_print_order_export_path, params: { message: "Danke 😀", order_id: @other_order.id }
    assert_response :unprocessable_entity
    assert_select "p", text: /unterstützt folgende Zeichen nicht/
  end

  test "very tall messages return a layout error rather than create additional pages" do
    post download_admin_print_order_export_path, params: { message: "Zeile\n" * 100 }
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /passt nicht auf eine Seite/
  end

  test "address settings offer defaults an inline preview and protected download" do
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    get addresses_admin_print_order_export_path, params: { year: @year }
    assert_response :success
    assert_equal "text/html", response.media_type
    assert_select "h1", text: "Adressetiketten vorbereiten"
    assert_select "#label_layout_columns[value='2']"
    assert_select "#label_layout_rows[value='8']"
    assert_select "#print-label-form input[type=number]", count: 11
    assert_select "iframe[name=label-preview]"
    token = css_select("#print-label-form input[name=authenticity_token]").sole["value"]
    custom = { columns: 2, rows: 7, margin_top: 12.5, gap_vertical: 2 }

    post address_preview_admin_print_order_export_path, params: { authenticity_token: token, label_layout: custom }
    assert_response :success
    assert_includes response.headers["Content-Disposition"], "inline"
    preview_page = pdf.pages.sole
    post download_addresses_admin_print_order_export_path, params: { authenticity_token: token, label_layout: custom }
    assert_response :success
    assert_includes response.headers["Content-Disposition"], "attachment"
    printed_page = pdf.pages.sole
    assert_equal preview_page.text, printed_page.text
    assert_equal preview_page.runs.map { |run| [ run.x, run.y ] }, printed_page.runs.map { |run| [ run.x, run.y ] }
    assert_operator preview_page.raw_content.scan(/\bre\b/).size, :>, 0, "Preview must contain label outlines"
    assert_equal 0, printed_page.raw_content.scan(/\bre\b/).size, "Downloads must not print label outlines"
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  test "invalid label geometry is explained and preserves the settings for correction" do
    post download_addresses_admin_print_order_export_path, params: { label_layout: { columns: 6, margin_left: 99, margin_top: 12.5 } }
    assert_response :unprocessable_entity
    assert_select "h1", text: "Adressetiketten vorbereiten"
    assert_select "[role=alert]", text: /zu schmal/
    assert_select "#label_layout_columns[value='6']"
    assert_select "#label_layout_margin_top[value='12.5']"
    assert_select "iframe[src='about:blank']"
    post address_preview_admin_print_order_export_path, params: { label_layout: { rows: 0 } }
    assert_response :unprocessable_entity
    assert_select "h1", text: "Vorschau konnte nicht erstellt werden"
    assert_select "p", text: /Reihen/
    assert_select ".admin-shell", count: 0
  end

  private

  def assert_vector_logo(page)
    # The flame logo is drawn with Bézier curves; the rest of the letter uses
    # only text and straight rules. Check actual vector output on each page.
    curves = []
    receiver = Object.new
    receiver.define_singleton_method(:append_curved_segment) { |*points| curves << points }
    page.walk(receiver)
    assert_predicate curves, :any?, "The letter must include the vector logo"
  end

  # PDF::Reader discards narrow whitespace in this embedded font. Content is
  # checked independently of spacing; the rendered PDFs are also reviewed.
  def assert_pdf_includes(text, expected)
    assert_includes text.gsub(/\s/, ""), expected.gsub(/\s/, "")
  end

  def assert_pdf_not_includes(text, expected)
    assert_not_includes text.gsub(/\s/, ""), expected.gsub(/\s/, "")
  end

  def order_for(user, product, quantity, year: @year)
    order = user.print_orders.create!(year: year)
    order.items.create!(print_product: product, quantity: quantity)
    order
  end

  def pdf
    PDF::Reader.new(StringIO.new(response.body))
  end
end
