require "test_helper"
require "rake"

class AdminParticipationTest < ActionDispatch::IntegrationTest
  test "admin lists share the search filter and pagination shell" do
    sign_in users(:admin)
    [ admin_users_path, admin_stores_path, admin_participations_path, admin_print_orders_path,
      admin_print_products_path, admin_orders_path, admin_products_path, admin_transactions_path,
      admin_transaction_requests_path ].each do |path|
      get path
      assert_response :success
      assert_select ".drawer-content > .admin-list-header", count: 1
      assert_select ".drawer-content > main.admin-list-scroll", count: 1
      assert_select ".drawer-content > .admin-list-footer", count: 1
      assert_select ".admin-list-header form[method=get] input[type=search][name=q]", count: 1
      assert_select "button[aria-label='Filter öffnen'][aria-haspopup=dialog]", count: 1
      assert_select "dialog#admin-list-filters select", minimum: 1
      assert_select ".admin-list-footer nav[aria-label=Seitennavigation]", count: 1
      assert_select "main .admin-list-header, main .admin-list-footer", count: 0
    end
  end

  test "user search combines names businesses roles and confirmation filters" do
    sign_in users(:admin)
    get admin_users_path, params: { q: "Person", role: "0", confirmation: "confirmed" }
    assert_select "tbody tr", count: 1
    assert_select "tbody", text: /member@example.com/
    get admin_users_path, params: { q: "Testgeschäft", role: "1" }
    assert_select ".admin-list-empty", text: "Keine Benutzer gefunden."
    users(:member).update_column(:confirmed_at, nil)
    get admin_users_path, params: { q: "Testgeschäft", confirmation: "pending" }
    assert_select "tbody tr", count: 1
    assert_select "tbody", text: /member@example.com/
    get admin_users_path, params: { q: "%" }
    assert_select ".admin-list-empty"
  end

  test "business search combines owner and status and preserves sorting" do
    businesses(:other).update!(status: :pending)
    sign_in users(:admin)
    get admin_stores_path, params: { q: "other@example", status: "pending", sort: "name_desc" }
    assert_select "tbody tr", count: 1
    assert_select "tbody", text: /Anderes Geschäft/
    assert_select "dialog option[selected][value=pending]"
    get admin_stores_path, params: { q: "other@example", status: "confirmed" }
    assert_select ".admin-list-empty"
    get admin_stores_path, params: { sort: "name_desc" }
    assert_select "tbody tr:first-child", text: /Testgeschäft/
  end

  test "payment filters distinguish outstanding differences from fully paid memberships" do
    low = participation_for(category: "no_listing", paid: true)
    low.request_upgrade("leist_member")
    participation_for(users(:other), paid: true)
    participation_for(users(:admin))
    participation_for(year: EventConfiguration.year - 1)
    sign_in users(:admin)
    get admin_participations_path, params: { payment_status: "pending" }
    assert_select "tbody tr", count: 2
    assert_select "tbody", text: /Differenzzahlung offen/
    get admin_participations_path, params: { payment_status: "paid" }
    assert_select "tbody tr", count: 1
    assert_select "tbody", text: /other@example.com/
    get admin_participations_path, params: { payment_status: "upgrade_pending", category: "no_listing", q: "Testgeschäft" }
    assert_select "tbody tr", count: 1
    assert_select "tbody", text: /member@example.com/
    get admin_participations_path, params: { year: EventConfiguration.year - 1 }
    assert_select "tbody tr", count: 1
    assert_select "tbody", text: /#{EventConfiguration.year - 1}/
  end

  test "print order filters find material and empty orders without changing annual totals" do
    order = users(:member).print_orders.create!(year: EventConfiguration.year)
    order.update_quantities({ print_products(:posters).id.to_s => "2" }, products: PrintProduct.all)
    users(:other).print_orders.create!(year: EventConfiguration.year)
    sign_in users(:admin)
    get admin_print_orders_path, params: { product_id: print_products(:posters).id, q: "Testgeschäft" }
    assert_select ".admin-list-scroll tbody tr", count: 1
    assert_select ".admin-list-scroll tbody", text: /member@example.com/
    get admin_print_orders_path, params: { contents: "empty" }
    assert_select ".admin-list-scroll tbody tr", count: 1
    assert_select ".admin-list-scroll tbody", text: /other@example.com/
    assert_select "strong", text: "2 Bündel"
    get admin_print_orders_path, params: { contents: "ordered", q: "other@example" }
    assert_select ".admin-list-empty"
    get admin_print_products_path, params: { active: "false", q: "Altes" }
    assert_select "tbody tr", count: 1
    assert_select "tbody", text: /Altes Material/
  end

  test "pagination preserves filters and safely handles invalid or out of range values" do
    12.times do |index|
      User.create!(email: "list-#{index}@example.com", password: "password123", role: 0, confirmed_at: Time.current)
    end
    sign_in users(:admin)
    query = { q: "list-", role: "0", confirmation: "confirmed", per: 10 }
    get admin_users_path, params: query
    assert_select "tbody tr", count: 10
    next_link = css_select(".admin-list-footer a[rel=next]").sole["href"]
    assert_equal query.stringify_keys.transform_values(&:to_s).merge("page" => "2"), Rack::Utils.parse_nested_query(URI(next_link).query)
    get next_link
    assert_select "tbody tr", count: 2
    assert_select ".admin-list-footer input[name=role][value='0']"
    get admin_users_path, params: query.merge(page: 999)
    assert_response :success
    assert_select "tbody tr", count: 2
    get admin_users_path, params: { per: -1, page: -1, role: "invalid" }
    assert_response :success
    assert_select "#list-per-page option[selected][value='20']"
    get admin_participations_path, params: { year: "invalid", category: "invalid" }
    assert_response :success
    assert_select "input[name=year][value=?]", EventConfiguration.year.to_s
  end

  test "legacy lists also search and filter their actual rows" do
    product = Product.create!(user: users(:member), title: "Testartikel", description: "Artikel",
      price: 12, main_product_image: "test.jpg", delievry_time: "2 Tage")
    Order.create!(product: product, customer: users(:other), quantity: 2, size: "M", order_no: "ORDER-123", accept_order: "accepted")
    Payment.create!(user: users(:other), payment_image: "test.jpg", plan: "Testplan", is_verified: "Pending")
    sign_in users(:admin)
    get admin_products_path, params: { q: "Testgeschäft", sort: "price_asc" }
    assert_response :success
    assert_select "tbody tr", count: 1
    get admin_orders_path, params: { q: "ORDER-123", status: "accepted" }
    assert_response :success
    assert_select "tbody tr", count: 1
    get admin_transactions_path, params: { q: "Testplan", status: "pending" }
    assert_response :success
    assert_select "tbody tr", count: 1
    get admin_transactions_path, params: { q: "Testplan", status: "approved" }
    assert_select ".admin-list-empty"
    get admin_transaction_requests_path, params: { q: "Testplan", sort: "oldest" }
    assert_response :success
    assert_select "tbody tr", count: 1
  end

  test "normal user cannot mark their membership paid or use admin screens" do
    participation = participation_for
    sign_in users(:member)
    patch admin_participation_path(id: participation.id), params: { participation: { payment_status: "paid" } }
    assert_redirected_to root_path
    assert participation.reload.pending?
    get admin_print_products_path
    assert_redirected_to root_path
    patch admin_print_distribution_path, params: { print_distribution: { distribution_on: "2026-11-20" } }
    assert_redirected_to root_path
    assert_nil PrintDistribution.current.distribution_on
  end

  test "admin sets clears and validates the distribution date shown to members" do
    sign_in users(:admin)
    get admin_print_products_path
    assert_select "input[type=date][name=?]", "print_distribution[distribution_on]"
    date = Date.new(EventConfiguration.year, 11, 20)
    patch admin_print_distribution_path, params: { print_distribution: { distribution_on: date.iso8601, year: 2040 } }
    assert_redirected_to admin_print_products_path
    assert_equal date, PrintDistribution.current.distribution_on
    assert_equal 1, PrintDistribution.where(year: EventConfiguration.year).count

    patch admin_print_distribution_path, params: { print_distribution: { distribution_on: "invalid" } }
    assert_response :unprocessable_entity
    assert_select ".alert-error", text: /gültiges Datum/
    assert_equal date, PrintDistribution.current.distribution_on

    sign_in users(:member)
    [ edit_app_print_order_path, app_print_order_path ].each do |path|
      get path
      assert_response :success
      assert_select "time[datetime=?]", date.iso8601, text: "20.11.#{EventConfiguration.year}"
      assert_select "section[aria-labelledby=print-delivery-heading].alert", count: 0
    end
    sign_in users(:admin)
    patch admin_print_distribution_path, params: { print_distribution: { distribution_on: "" } }
    assert_redirected_to admin_print_products_path
    assert_nil PrintDistribution.current.distribution_on
  end

  test "a previous event distribution date is not displayed for the current event" do
    PrintDistribution.create!(year: EventConfiguration.year - 1, distribution_on: Date.new(EventConfiguration.year - 1, 11, 20))
    sign_in users(:member)
    get app_print_order_path
    assert_select "section[aria-labelledby=print-delivery-heading]", text: /Das Datum wird noch bekannt gegeben/
    assert_select "time", count: 0
  end

  test "admin manages the annual order deadline with date validation" do
    sign_in users(:admin)
    deadline = Date.new(EventConfiguration.year, 11, 15)
    distribution_date = deadline + 5
    get admin_print_products_path
    assert_select "input[type=date][name=?]", "print_distribution[order_deadline_on]"
    patch admin_print_distribution_path, params: { print_distribution: { distribution_on: distribution_date.iso8601, order_deadline_on: deadline.iso8601 } }
    assert_redirected_to admin_print_products_path
    assert_equal deadline, PrintDistribution.current.order_deadline_on
    [ "invalid", (distribution_date + 1).iso8601 ].each do |invalid|
      patch admin_print_distribution_path, params: { print_distribution: { order_deadline_on: invalid } }
      assert_response :unprocessable_entity
      assert_equal deadline, PrintDistribution.current.order_deadline_on
    end
    patch admin_print_distribution_path, params: { print_distribution: { order_deadline_on: "" } }
    assert_redirected_to admin_print_products_path
    assert_nil PrintDistribution.current.order_deadline_on
    assert PrintDistribution.current.orders_open?
  end

  test "admin can mark paid and unpaid with dates maintained by the model" do
    participation = participation_for
    sign_in users(:admin)
    patch admin_participation_path(id: participation.id), params: { participation: { payment_status: "paid", paid_at: 10.years.ago, amount_cents: 1 } }
    assert_redirected_to admin_user_path(id: users(:member).id)
    assert participation.reload.paid?
    assert participation.paid_at > 1.minute.ago
    assert_equal 20_000, participation.amount_cents
    patch admin_participation_path(id: participation.id), params: { participation: { payment_status: "pending" } }
    assert participation.reload.pending?
    assert_nil participation.paid_at
  end

  test "admin user and store drilldowns expose current and historical payment data" do
    participation_for(year: EventConfiguration.year - 1, paid: true)
    current = participation_for(category: "no_listing")
    sign_in users(:admin)
    get admin_user_path(id: users(:member).id)
    assert_response :success
    assert_select "h2", text: "Zahlungen"
    assert_select "dd", text: current.category_title
    assert_select "section[aria-labelledby=store-payments-heading] td", text: /#{EventConfiguration.year - 1}/
    get admin_store_path(id: businesses(:member).id)
    assert_response :success
    assert_select "a[href=?]", admin_user_path(id: users(:member).id)
    assert_select "dd", text: "Kein Eintrag"
  end

  test "user detail exposes account context and related records without security secrets" do
    user = users(:member)
    user.update_columns(management_name: "Kontakt Beispiel", unconfirmed_email: "pending@example.com",
      failed_attempts: 2, confirmation_token: "secret-confirmation", reset_password_token: "secret-reset",
      unlock_token: "secret-unlock", otp: "secret-otp", legacy_password_hash: "secret-hash",
      payment_method: "Überweisung", current_sign_in_ip: "192.0.2.1")
    own_order = user.print_orders.create!(year: EventConfiguration.year)
    foreign_order = users(:other).print_orders.create!(year: EventConfiguration.year)
    sign_in users(:admin)
    get admin_user_path(id: user.id)
    assert_response :success
    assert_select ".drawer-content > .admin-detail-header h1", text: user.name
    assert_select "section[aria-labelledby=user-store-heading] a[href=?]", admin_store_path(businesses(:member))
    [ "pending@example.com", "Kontakt Beispiel", "192.0.2.1", "Überweisung" ].each { |value| assert_select "dd", text: value }
    assert_select "main a[href=?]", admin_print_order_path(own_order)
    assert_select "main a[href=?]", admin_print_order_path(foreign_order), count: 0
    assert_no_match(/secret-(confirmation|reset|unlock|otp|hash)/, response.body)
    user.update!(deleted: true)
    get admin_user_path(id: user.id)
    assert_select "dd", text: "Deaktiviert"
    assert_select "button", text: "Als Benutzer anmelden", count: 0
  end

  test "only a superadmin can promote an existing admin and all other role changes are rejected" do
    superadmin = User.create!(email: "superadmin@example.com", password: "password123", role: 2, confirmed_at: Time.current)
    sign_in users(:admin)
    get admin_user_path(id: users(:other).id)
    assert_select "button", text: "Zum Superadmin ernennen", count: 0
    patch admin_user_path(id: users(:admin).id), params: { user: { role: 2 } }
    assert_redirected_to admin_users_path
    assert users(:admin).reload.admin?

    sign_in superadmin
    get admin_user_path(id: users(:member).id)
    assert_select "button", text: "Zum Superadmin ernennen", count: 0
    [ 1, 2 ].each do |role|
      patch admin_user_path(id: users(:member).id), params: { user: { role: role } }
      assert_response :unprocessable_entity
      assert_select ".alert-error", text: /nur von Admin zu Superadmin/
      assert users(:member).reload.user?
      assert_not users(:member).update(role: role)
    end
    patch admin_user_path(id: users(:admin).id), params: { user: { role: 0 } }
    assert_response :unprocessable_entity
    assert users(:admin).reload.admin?
    get admin_user_path(id: users(:admin).id)
    assert_select "button[data-turbo-confirm]", text: "Zum Superadmin ernennen"
    patch admin_user_path(id: users(:admin).id), params: { user: { role: 2, email: "changed@example.com" } }
    assert_redirected_to admin_user_path(id: users(:admin).id)
    assert users(:admin).reload.superadmin?
    assert_equal "admin@example.com", users(:admin).email
    get admin_user_path(id: users(:admin).id)
    assert_select "button", text: "Zum Superadmin ernennen", count: 0
    patch admin_user_path(id: users(:admin).id), params: { user: { role: 1 } }
    assert_response :unprocessable_entity
    assert users(:admin).reload.superadmin?
  end

  test "cleared list searches retain the filters and reset pagination" do
    sign_in users(:admin)
    get admin_users_path, params: { q: "member", role: 0, per: 10 }
    assert_select "input[type=search][data-admin-list-target=search][data-action*='input->admin-list#searchChanged']"
    assert_select "form[role=search] input[name=page]", count: 0
    get admin_users_path, params: { q: "", role: 0, per: 10 }
    assert_select "tbody tr", count: 2
    assert_select "#list-per-page option[selected][value='10']"
    assert_select "dialog select[name=role] option[selected][value='0']"
  end

  test "print product editors are card free and keep validation inside the fixed bar layout" do
    product = print_products(:posters)
    sign_in users(:admin)
    [ new_admin_print_product_path, edit_admin_print_product_path(id: product.id) ].each do |path|
      get path
      assert_response :success
      assert_select "main .admin-card", count: 0
      assert_select ".drawer-content > .app-topbar"
      assert_select ".drawer-content > .app-bottombar button[form=print-product-form]"
      assert_select "form#print-product-form[data-unsaved-changes-target=form]"
      assert_select "input[type=file][accept*='image/jpeg']"
      assert_select "input[name='print_product[active]'][type=checkbox]"
    end
    patch admin_print_product_path(id: product.id), params: { print_product: { title: "", description: "Geänderter Inhalt", position: -1 } }
    assert_response :unprocessable_entity
    assert_select "form#print-product-form[data-invalid=true]"
    assert_select ".alert-error"
    assert_select "textarea", text: "Geänderter Inhalt"
    assert_select ".drawer-content > .app-bottombar button[form=print-product-form]"
    assert_equal "3 × Plakate", product.reload.title
  end

  test "store overview presents complete business details and the linked owner without status banners" do
    business = businesses(:member)
    business.update!(contact_name: "Kontaktperson Beispiel", email: "kontakt@example.com",
      website: "https://example.com/shop", instagram: "https://instagram.com/testshop",
      tiktok: "https://tiktok.com/@testshop", linkedin: "https://linkedin.com/company/testshop",
      facebook: "https://facebook.com/testshop", billing_address: "Rechnungsgasse 9\n3011 Bern",
      description: "<p>Unser Sortiment</p>", first_advent_specialities: "<p>Adventsangebot</p>")
    business.main_image.attach(io: File.open(Rails.root.join("app/assets/images/placeholder.png")), filename: "store.png", content_type: "image/png")
    sign_in users(:admin)
    get admin_store_path(id: business.id)
    assert_response :success
    assert_select ".drawer-content > .admin-detail-header h1", text: business.business_name
    assert_select ".drawer-content > main.admin-detail-scroll"
    assert_select "main .alert, main .badge, [data-controller=dismiss]", count: 0
    assert_select "a[href=?]", edit_admin_store_path(id: business.id), text: "Informationen bearbeiten"
    assert_select ".admin-detail-header a[href=?]", preview_admin_store_path(id: business.id), text: "Geschäftseintrag ansehen"
    assert_select "section[aria-labelledby=store-user-heading] a[href=?]", admin_user_path(users(:member))
    [ "Kontaktperson Beispiel", "031 123 45 67", "Einzelhandel" ].each do |value|
      assert_select "dd", text: value
    end
    assert_select "dd", text: /Rechnungsgasse 9\s+3011 Bern/
    assert_select "a[href='mailto:kontakt@example.com']"
    [ business.website, business.instagram, business.tiktok, business.linkedin, business.facebook, business.map_link ].each do |url|
      assert_select "main a[href=?]", url
    end
    assert_select ".trix-content", text: /Unser Sortiment/
    assert_select ".trix-content", text: /Adventsangebot/
    assert_select "img[alt=?]", "Hauptbild – #{business.business_name}"
    assert_select "form[action=?] select[name='business[status]']", admin_store_path(id: business.id)
    assert_select "form[action=?][data-turbo-confirm]", admin_store_path(id: business.id)
    headings = css_select("main section[aria-labelledby]").map { |section| section["aria-labelledby"] }
    assert_operator headings.index("store-orders-heading"), :<, headings.index("store-payments-heading")
    assert_operator headings.index("store-payments-heading"), :<, headings.index("store-online-heading")
  end

  test "store histories contain only its orders and payments with upgrades counted as differences" do
    participation = participation_for(category: "no_listing", paid: true)
    participation.update!(payment_reference: "initial-payment")
    upgrade = participation.request_upgrade("non_leist_member")
    upgrade.mark_paid!
    upgrade.update!(payment_provider: "dummy", payment_reference: "upgrade-payment")
    participation_for(year: EventConfiguration.year - 1)
    foreign = participation_for(users(:other), paid: true)
    foreign.update!(payment_reference: "foreign-payment")
    order = users(:member).print_orders.create!(year: EventConfiguration.year)
    order.update_quantities({ print_products(:posters).id.to_s => "2" }, products: PrintProduct.all)
    foreign_order = users(:other).print_orders.create!(year: EventConfiguration.year)

    sign_in users(:admin)
    get admin_store_path(id: businesses(:member).id)
    assert_response :success
    assert_select ".admin-detail-header a[href=?]", marketing_store_path(businesses(:member)), text: "Geschäftseintrag ansehen"
    assert_select "section[aria-labelledby=store-administration-heading] dd", text: "Bezahlt"
    assert_select "section[aria-labelledby=store-orders-heading]" do
      assert_select "tbody tr", count: 1
      assert_select "a[href=?]", admin_print_order_path(order), text: "Printbestellung #{EventConfiguration.year}"
      assert_select "li", text: "2 Bündel × #{print_products(:posters).title}"
      assert_select "a[href=?]", admin_print_order_path(foreign_order), count: 0
    end
    assert_select "section[aria-labelledby=store-payments-heading]" do
      assert_select "tbody tr", count: 3
      assert_select "td", text: "CHF 100.00"
      assert_select "td", text: "CHF 150.00"
      assert_select "td", text: "CHF 250.00", count: 0
      assert_select "p", text: "initial-payment"
      assert_select "p", text: "upgrade-payment"
      assert_select "p", text: "foreign-payment", count: 0
      assert_select "td", text: /Testzahlung · kein echter Geldfluss/
      assert_select "form[action=?]", admin_participation_path(participation), count: 0
    end
  end

  test "store overview handles missing records and unsafe links and retains approval controls" do
    business = businesses(:member)
    business.update!(website: "javascript:alert(1)")
    sign_in users(:admin)
    %w[pending confirmed rejected deleted].each do |status|
      business.update!(status: status)
      get admin_store_path(id: business.id)
      assert_response :success
      assert_select "main .alert, main .badge", count: 0
      assert_select "select[name='business[status]'] option[selected][value=?]", status
    end
    assert_select "a[href^='javascript:']", count: 0
    assert_select "section[aria-labelledby=store-images-heading]", text: /Noch keine Bilder/
    assert_select "section[aria-labelledby=store-orders-heading]", text: /noch keine Printbestellungen/
    assert_select "section[aria-labelledby=store-payments-heading]", text: /noch keine Zahlungen/
    assert_select ".admin-detail-field", text: /Mitgliedschaftsstatus\s+Noch nicht ausgewählt/
    patch admin_store_path(id: business.id), params: { business: { status: "confirmed" } }
    assert_redirected_to admin_store_path(id: business.id)
    assert business.reload.confirmed?
    sign_in users(:member)
    get admin_store_path(id: business.id)
    assert_redirected_to root_path
  end

  test "store payment history keeps an eligible pending upgrade actionable" do
    participation = participation_for(category: "no_listing", paid: true)
    upgrade = participation.request_upgrade("leist_member")
    sign_in users(:admin)
    get admin_store_path(id: businesses(:member).id)
    assert_select "section[aria-labelledby=store-administration-heading] dd", text: "Bisherige Mitgliedschaft bezahlt · Differenzzahlung offen"
    assert_select "section[aria-labelledby=store-payments-heading]" do
      assert_select "form[action=?]", admin_participation_upgrade_path(upgrade)
      assert_select "button", text: "Differenzzahlung bestätigen"
      assert_select "form[action=?]", admin_participation_path(participation), count: 0
    end
  end

  test "admin store entry preview is private and does not publish an ineligible store" do
    business = businesses(:member)
    business.update!(status: :pending)
    participation_for(category: "no_listing")
    sign_in users(:admin)
    get admin_store_path(id: business.id)
    assert_select ".admin-detail-field", text: /Mitgliedschaftsstatus\s+Zahlung offen · Teilnahme nicht abgeschlossen/
    get preview_admin_store_path(id: business.id)
    assert_response :success
    assert_select "h1", text: business.business_name
    assert_select "p", text: "Vorschau des Geschäftseintrags · nur für Administratoren"
    assert_select "a[href=?]", admin_store_path(id: business.id), text: "Zurück zur Geschäftsübersicht"
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
    assert_includes response.headers["Cache-Control"], "no-store"
    assert business.reload.pending?
    assert_not business.publicly_visible?
    get marketing_store_path(business)
    assert_redirected_to marketing_stores_path
    sign_in users(:member)
    get preview_admin_store_path(id: business.id)
    assert_redirected_to root_path
    sign_out users(:member)
    get preview_admin_store_path(id: business.id)
    assert_redirected_to admin_login_path
  end

  test "admin product CRUD supports activation and position" do
    sign_in users(:admin)
    assert_difference "PrintProduct.count" do
      post admin_print_products_path, params: { print_product: { title: "Tischsteller", description: "10 Stück pro Bündel", active: "1", position: "4" } }
    end
    product = PrintProduct.order(:created_at).last
    assert_redirected_to admin_print_products_path
    patch admin_print_product_path(product), params: { print_product: { title: "Tischsteller neu", description: product.description, active: "0", position: "2" } }
    assert_redirected_to admin_print_products_path
    assert_equal [ "Tischsteller neu", false, 2 ], product.reload.attributes.values_at("title", "active", "position")
  end

  test "initial bundle seed is idempotent and preserves admin changes" do
    Rake::Task.define_task(:environment) unless Rake::Task.task_defined?(:environment)
    load Rails.root.join("lib/tasks/print_materials.rake") unless Rake::Task.task_defined?("print_materials:seed")
    task = Rake::Task["print_materials:seed"]
    task.reenable
    assert_difference "PrintProduct.count", 3 do
      task.invoke
    end
    posters = PrintProduct.find_by!(seed_key: "posters")
    assert_not PrintProduct.where.not(seed_key: nil).any? { |product| product.description.include?("Gratis") }
    postcards = PrintProduct.find_by!(seed_key: "postcards")
    postcards.update!(description: "Ein Bündel mit 50 Postkarten im Format A6. Gratis.")
    maps = PrintProduct.find_by!(seed_key: "city_maps")
    maps.update!(description: "Von der Administration angepasster Text.")
    posters.update!(title: "Angepasstes Plakatbündel", active: false)
    task.reenable
    assert_no_difference "PrintProduct.count" do
      task.invoke
    end
    assert_equal "Angepasstes Plakatbündel", posters.reload.title
    assert_not posters.active?
    assert_equal "Ein Bündel mit 50 Postkarten im Format A6.", postcards.reload.description
    assert_equal "Von der Administration angepasster Text.", maps.reload.description
  end

  test "admin can attach and render a product image using Active Storage" do
    sign_in users(:admin)
    image = Rack::Test::UploadedFile.new(Rails.root.join("app/assets/images/placeholder.png"), "image/png")
    post admin_print_products_path, params: { print_product: { title: "Mit Bild", description: "Ein Bündel", image: image } }
    assert_redirected_to admin_print_products_path
    product = PrintProduct.order(:created_at).last
    assert product.image.attached?
    get edit_admin_print_product_path(product)
    assert_response :success
    assert_select "img[alt=?]", "Mit Bild"
    get admin_print_products_path
    assert_response :success
  end

  test "non image upload is rejected with validation errors" do
    sign_in users(:admin)
    upload = Rack::Test::UploadedFile.new(Rails.root.join("README.md"), "text/plain")
    assert_no_difference "PrintProduct.count" do
      post admin_print_products_path, params: { print_product: { title: "Ungültiges Bild", description: "Bündel", image: upload } }
    end
    assert_response :unprocessable_entity
    assert_select ".alert-error", text: /muss ein Bild/
  end

  test "admin payment overview and print editing screens render" do
    participation_for
    order = users(:member).print_orders.create!(year: EventConfiguration.year)
    sign_in users(:admin)
    get admin_participations_path
    assert_response :success
    assert_select "td", text: /Zahlung offen/
    get admin_print_order_path(order)
    assert_response :success
    get edit_admin_print_order_path(order)
    assert_response :success
    get new_admin_print_product_path
    assert_response :success
    get admin_root_path
    assert_response :success
  end

  test "admin print order overview includes totals and can correct any catalogue quantity" do
    order = users(:member).print_orders.create!(year: EventConfiguration.year)
    order.update_quantities({ print_products(:posters).id.to_s => "2" }, products: PrintProduct.all)
    sign_in users(:admin)
    get admin_print_orders_path
    assert_response :success
    assert_select "strong", text: "2 Bündel"
    patch admin_print_order_path(order), params: { quantities: { print_products(:posters).id => "3", print_products(:inactive).id => "1" } }
    assert_redirected_to admin_print_order_path(order)
    assert_equal 4, order.reload.items.sum(:quantity)
  end

  test "admin can edit business details while eligibility remains explicit" do
    participation_for(category: "no_listing", paid: true)
    previous_updated_at = businesses(:member).updated_at
    sign_in users(:admin)
    get edit_admin_store_path(id: businesses(:member).id)
    assert_response :success
    assert_select ".drawer-content[data-controller=unsaved-changes] > .app-topbar"
    assert_select ".drawer-content > .app-bottombar button[form=business-form]", text: "Änderungen speichern"
    assert_select "main .app-bottombar", count: 0
    assert_select "form#business-form[action=?][data-unsaved-changes-target=form]", admin_store_path(id: businesses(:member).id)
    assert_select ".form-section", count: 5
    assert_select "[data-controller=multiselect]"
    assert_select "textarea[name='business[billing_address]']"
    assert_select "input[type=file]", count: 4
    assert_select "trix-editor", count: 2
    assert_select "a[href^='/app/']", count: 0
    travel 1.minute do
      patch admin_store_path(id: businesses(:member).id), params: { business: { business_name: "Korrigiertes Geschäft", status: "confirmed" } }
    end
    assert_redirected_to admin_store_path(id: businesses(:member).id)
    assert_equal "Korrigiertes Geschäft", businesses(:member).reload.business_name
    assert_not businesses(:member).publicly_visible?
    assert_operator businesses(:member).updated_at, :>, previous_updated_at
    get admin_store_path(id: businesses(:member).id)
    assert_select ".admin-detail-field", text: /Geändert am/
    assert_select "time[datetime=?]", businesses(:member).updated_at.iso8601
  end

  test "admin business editor preserves invalid entries and saves rich content categories and images" do
    business = businesses(:member)
    sign_in users(:admin)
    patch admin_store_path(id: business.id), params: { business: { business_name: "", categories: [ "", "Einzelhandel" ], contact_name: "Neue Kontaktperson" } }
    assert_response :unprocessable_entity
    assert_select "form#business-form[data-invalid=true]"
    assert_select ".alert-error"
    assert_select "input[name='business[contact_name]'][value='Neue Kontaktperson']"
    assert_select "input[name='business[categories][]'][value=Einzelhandel][checked]"
    assert_select ".drawer-content > .app-bottombar button[data-unsaved-changes-target=save]"
    assert_equal "Testgeschäft", business.reload.business_name

    image = Rack::Test::UploadedFile.new(Rails.root.join("app/assets/images/placeholder.png"), "image/png")
    patch admin_store_path(id: business.id), params: { business: {
      business_name: "Neue Angaben", categories: [ "" ], description: "<p>Neuer Beschrieb</p>",
      first_advent_specialities: "<p>Neues Adventsangebot</p>", main_image: image, user_id: users(:other).id
    } }
    assert_redirected_to admin_store_path(id: business.id)
    assert_empty business.reload.categories
    assert_equal users(:member).id, business.user_id
    assert_equal "Neuer Beschrieb", business.description.to_plain_text
    assert_equal "Neues Adventsangebot", business.first_advent_specialities.to_plain_text
    assert business.main_image.attached?
    get edit_admin_store_path(id: business.id)
    assert_select "img#preview-main_image"
    assert_select "a[data-turbo-method=delete]", count: 0
  end
end
