require "test_helper"
require "zip"

class BusinessExportTest < ActiveSupport::TestCase
  setup do
    businesses(:member).update!(
      business_name: "Zytglogge Atelier",
      address: "Aarbergergasse 20, 3011 Bern",
      categories: [ "Floristik", "Dekoration" ],
      status: :confirmed,
      contact_name: "Anna Beispiel",
      email: "atelier@example.com",
      website: "atelier.example.com"
    )
    businesses(:other).update!(
      business_name: "Altstadt Spiele",
      address: "Kramgasse 2, 3011 Bern",
      status: :pending
    )
  end

  test "defaults to all statuses ordered by address" do
    export = BusinessExport.new

    assert_equal "address_asc", export.sort
    assert_nil export.status
    assert_equal [ businesses(:member).id, businesses(:other).id ], export.businesses.map(&:id)
  end

  test "sorts by business name and filters by an allowlisted status" do
    export = BusinessExport.new(sort: "name_asc", status: "pending")

    assert_equal [ businesses(:other).id ], export.businesses.map(&:id)

    all_by_name = BusinessExport.new(sort: "name_asc")
    assert_equal [ businesses(:other).id, businesses(:member).id ], all_by_name.businesses.map(&:id)
  end

  test "invalid selections safely fall back to all statuses and address ordering" do
    export = BusinessExport.new(sort: "businesses.id DESC", status: "unknown")

    assert_equal "address_asc", export.sort
    assert_nil export.status
    assert_equal [ businesses(:member).id, businesses(:other).id ], export.businesses.map(&:id)
  end

  test "rows use the documented columns and human readable values" do
    row = BusinessExport.new(status: "confirmed").rows.sole

    assert_equal [
      "Zytglogge Atelier",
      "Aarbergergasse 20, 3011 Bern",
      "Floristik, Dekoration",
      "Bestätigt",
      "Anna Beispiel",
      businesses(:member).phone,
      "atelier@example.com",
      users(:member).email,
      businesses(:member).billing_address,
      "atelier.example.com"
    ], row
  end

  test "xlsx is valid enough to unzip has matching rows and never emits formulas" do
    businesses(:member).update!(
      business_name: "=HYPERLINK(\"https://example.com\")",
      address: "+1+1",
      contact_name: "-1+1",
      phone: "@SUM(1,1)"
    )
    export = BusinessExport.new(status: "confirmed")

    workbook_xml = zip_xml(export.to_xlsx)
    worksheet = Nokogiri::XML(workbook_xml.fetch("xl/worksheets/sheet1.xml"))

    assert_equal 2, worksheet.xpath("//*[local-name()='sheetData']/*[local-name()='row']").size
    assert_empty worksheet.xpath("//*[local-name()='f']")
    workbook_content = workbook_xml.values.join
    [ "=HYPERLINK", "+1+1", "-1+1", "@SUM" ].each { |value| assert_includes workbook_content, value }
  end

  test "a legacy business without a status does not break the complete export" do
    businesses(:member).update_column(:status, nil)

    row = BusinessExport.new.rows.find { |values| values.first == "Zytglogge Atelier" }

    assert_equal "Unbekannt", row.fetch(3)
  end

  test "an empty selection produces a header only workbook" do
    export = BusinessExport.new(status: "rejected")
    worksheet = Nokogiri::XML(zip_xml(export.to_xlsx).fetch("xl/worksheets/sheet1.xml"))

    assert_empty export.rows
    assert_equal 1, worksheet.xpath("//*[local-name()='sheetData']/*[local-name()='row']").size
  end

  private

  def zip_xml(data)
    files = {}
    Zip::File.open_buffer(StringIO.new(data)) do |zip|
      zip.each do |entry|
        files[entry.name] = entry.get_input_stream.read if entry.name.end_with?(".xml")
      end
    end
    files
  end
end
