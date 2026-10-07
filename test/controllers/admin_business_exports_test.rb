require "test_helper"
require "zip"

class AdminBusinessExportsTest < ActionDispatch::IntegrationTest
  setup do
    businesses(:member).update!(address: "Aarbergergasse 20, 3011 Bern", status: :confirmed)
    businesses(:other).update!(address: "Kramgasse 2, 3011 Bern", status: :pending)
  end

  test "store list links to the export preview" do
    sign_in users(:admin)

    get admin_stores_path

    assert_response :success
    assert_select ".admin-list-titlebar a[href=?]", admin_business_export_path, text: /Excel-Export/
  end

  test "admin previews all businesses by address with controls and private headers" do
    sign_in users(:admin)

    get admin_business_export_path

    assert_response :success
    assert_equal %w[no-store private], response.headers["Cache-Control"].split(/,\s*/).sort
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
    assert_select "form[method=get][action=?]", admin_business_export_path do
      assert_select "select[name=sort] option[value=address_asc][selected]"
      assert_select "select[name=status] option:first-child[value='']", text: "Alle Status"
    end
    assert_select "table thead th", BusinessExport::HEADERS.size
    assert_select "table tbody tr", count: 2
    assert_select "table tbody tr:first-child", text: /Testgeschäft/
    assert_select "a[href=?]", download_admin_business_export_path(sort: "address_asc"), text: /Excel herunterladen/
  end

  test "preview applies name sorting and an optional status filter" do
    sign_in users(:admin)

    get admin_business_export_path, params: { sort: "name_asc", status: "pending" }

    assert_response :success
    assert_select "select[name=sort] option[value=name_asc][selected]"
    assert_select "select[name=status] option[value=pending][selected]"
    assert_select "table tbody tr", count: 1
    assert_select "table tbody", text: /Anderes Geschäft/
    assert_select "table tbody", text: /Testgeschäft/, count: 0
  end

  test "preview is not paginated and invalid selections use safe defaults" do
    21.times do |index|
      user = User.create!(email: "export-#{index}@example.com", password: "password123", confirmed_at: Time.current)
      Business.create!(
        user: user,
        business_name: "Export Geschäft #{index}",
        phone: "031 000 00 #{index.to_s.rjust(2, '0')}",
        address: "Münstergasse #{index + 1}, 3011 Bern",
        billing_address: "Münstergasse #{index + 1}, 3011 Bern",
        map_link: "",
        status: :confirmed
      )
    end
    sign_in users(:admin)

    get admin_business_export_path, params: { sort: "DROP TABLE businesses", status: "invalid" }

    assert_response :success
    assert_select "select[name=sort] option[value=address_asc][selected]"
    assert_select "select[name=status] option:first-child[value='']", text: "Alle Status"
    assert_select "table tbody tr", count: 23
  end

  test "admin downloads an xlsx matching the selected status" do
    sign_in users(:admin)

    get download_admin_business_export_path, params: { sort: "name_asc", status: "confirmed" }

    assert_response :success
    assert_equal "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", response.media_type
    assert_match(/attachment; filename="geschaefte-#{Date.current.iso8601}\.xlsx"/, response.headers["Content-Disposition"])
    assert_equal "PK", response.body.byteslice(0, 2)
    assert_equal %w[no-store private], response.headers["Cache-Control"].split(/,\s*/).sort
    workbook_xml = zip_xml(response.body).values.join
    assert_includes workbook_xml, "Testgesch"
    assert_not_includes workbook_xml, "Anderes Gesch"
  end

  test "empty status selection previews an empty state and downloads a workbook" do
    sign_in users(:admin)

    get admin_business_export_path, params: { status: "rejected" }
    assert_response :success
    assert_select ".admin-list-empty", text: "Keine Geschäfte für diesen Status gefunden."

    get download_admin_business_export_path, params: { status: "rejected" }
    assert_response :success
    assert_equal "PK", response.body.byteslice(0, 2)
  end

  test "all export endpoints require an admin" do
    endpoints = [ admin_business_export_path, download_admin_business_export_path ]

    endpoints.each do |path|
      get path
      assert_redirected_to admin_login_path
    end

    sign_in users(:member)
    endpoints.each do |path|
      get path
      assert_redirected_to root_path
    end
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
