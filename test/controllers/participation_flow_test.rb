require "test_helper"
require "minitest/mock"

class ParticipationFlowTest < ActionDispatch::IntegrationTest
  test "dashboard participation page is status only with a link to setup" do
    sign_in users(:member)
    get app_participation_path
    assert_response :success
    assert_select ".drawer-side"
    assert_select "input[type=radio]", count: 0
    assert_select "nav[aria-label=Anmeldeschritte]", count: 0
    assert_select "a[href=?]", edit_app_participation_path, text: "Mitgliedschaft auswählen"

    participation = participation_for
    get app_participation_path
    assert_select "a[href=?]", payment_app_participation_path, text: "Zur Zahlung"
    assert_select "a[href=?]", edit_app_participation_path(setup: 0), text: "Mitgliedschaft ändern"
    assert_select "a", text: "Teilnahme fortsetzen", count: 0
    assert_select "input[type=radio]", count: 0
    participation.mark_paid!
    get app_participation_path
    assert_select "a[href=?]", payment_app_participation_path, count: 0
    assert_select "a[href=?]", edit_app_participation_path(setup: 0), count: 0
  end

  test "dashboard payment uses its own layout without the setup guide" do
    participation = participation_for
    sign_in users(:member)
    get payment_app_participation_path
    assert_response :success
    assert_select "body[data-layout=payment]"
    assert_select ".drawer-side", count: 0
    assert_select "nav[aria-label=Anmeldeschritte]", count: 0
    assert_select ".app-bottombar a[href=?]", app_participation_path, text: "Zurück zur Mitgliedschaft"
    assert_select "a[href=?]", app_print_order_path(setup: 1), count: 0
    assert_select "a[href=?]", edit_app_participation_path, count: 0
    participation.mark_paid!
    get payment_app_participation_path
    assert_redirected_to app_participation_path
  end

  test "dummy membership payment requires explicit confirmation and preserves the setup return" do
    participation = participation_for
    sign_in users(:member)
    get payment_app_participation_path(setup: 1)
    assert_select "a[href=?]", app_test_payment_path(setup: 1), text: "Testzahlung öffnen"
    get app_test_payment_path(setup: 1)
    assert_response :success
    assert_select "body[data-layout=payment]"
    assert_select "nav[aria-label=Anmeldeschritte]", count: 0
    assert_select "button[form=test-payment-form]", text: "Ja, als bezahlt markieren"
    assert participation.reload.pending?
    token = Nokogiri::HTML(response.body).at_css("input[name=token]")["value"]
    post app_test_payment_path, params: { token: token, amount_cents: 1, user_id: users(:other).id }
    assert_redirected_to app_print_order_path(setup: 1)
    assert participation.reload.paid?
    assert_equal "dummy", participation.payment_provider
    assert_nil users(:other).current_participation
    original_paid_at = participation.paid_at
    post app_test_payment_path, params: { token: token }
    assert_equal original_paid_at, participation.reload.paid_at
    get app_participation_path
    assert_select "p", text: /Enthält eine Testzahlung/
  end

  test "dummy upgrade payment settles only the quoted upgrade even after a repeated submission" do
    participation = participation_for(category: "no_listing", paid: true)
    upgrade = participation.request_upgrade("leist_member")
    sign_in users(:member)
    get app_test_payment_path
    assert_select "p", text: "CHF 100.00"
    token = Nokogiri::HTML(response.body).at_css("input[name=token]")["value"]
    post app_test_payment_path, params: { token: token }
    assert_redirected_to app_participation_path
    assert upgrade.reload.paid?
    assert_equal "dummy", upgrade.payment_provider
    assert_equal "leist_member", participation.reload.category
    assert users(:member).business_editing_allowed?
    second = participation.request_upgrade("non_leist_member")
    assert_not second.persisted?
    post app_test_payment_path, params: { token: token }
    assert_redirected_to app_participation_path
    assert_equal 1, participation.upgrades.count
    assert_equal "leist_member", participation.reload.category
    assert_equal 0, participation.amount_due_cents
  end

  test "dummy payment rejects expired changed and foreign payment requests" do
    participation = participation_for
    sign_in users(:member)
    get app_test_payment_path
    token = Nokogiri::HTML(response.body).at_css("input[name=token]")["value"]
    post app_test_payment_path, params: { token: "invalid" }
    assert_response :unprocessable_entity
    travel 31.minutes do
      post app_test_payment_path, params: { token: token }
      assert_response :unprocessable_entity
    end
    participation.update!(category: "no_listing")
    post app_test_payment_path, params: { token: token }
    assert_response :conflict
    assert participation.reload.pending?
    sign_in users(:other)
    post app_test_payment_path, params: { token: token }
    assert_response :not_found
    assert participation.reload.pending?
  end

  test "dummy payment is unavailable in production for both pages and direct confirmation" do
    participation = participation_for
    sign_in users(:member)
    get app_test_payment_path
    token = Nokogiri::HTML(response.body).at_css("input[name=token]")["value"]
    Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new("production")) do
      assert_not EventConfiguration.dummy_payments_enabled?
      get payment_app_participation_path
      assert_response :success
      assert_select "a[href=?]", app_test_payment_path, count: 0
      get app_test_payment_path
      assert_response :not_found
      post app_test_payment_path, params: { token: token }
      assert_response :not_found
    end
    assert participation.reload.pending?
    sign_out users(:member)
    get app_test_payment_path
    assert_redirected_to new_user_session_path
    post app_test_payment_path, params: { token: token }
    assert_redirected_to new_user_session_path
  end

  test "paid membership upgrades show only higher prices and server calculated differences" do
    participation = participation_for(category: "no_listing", paid: true)
    sign_in users(:member)
    get edit_app_participation_path(setup: 0)
    assert_response :success
    assert_select "input[type=radio]", count: 2
    assert_select "p", text: "Noch zu bezahlen: CHF 100.00"
    assert_select "p", text: "Noch zu bezahlen: CHF 150.00"
    assert_select "nav[aria-label=Anmeldeschritte]", count: 0
    patch app_participation_path(setup: 0), params: { participation: { category: "leist_member", difference_cents: 1, amount_cents: 1, payment_status: "paid", user_id: users(:other).id } }
    assert_redirected_to payment_app_participation_path
    upgrade = participation.upgrades.sole
    assert_equal 10_000, upgrade.difference_cents
    assert upgrade.pending?
    assert_equal "no_listing", participation.reload.category
    follow_redirect!
    assert_select "body[data-layout=payment]"
    assert_select "p", text: "Jetzt zu bezahlen: CHF 100.00"
    assert_select "nav[aria-label=Anmeldeschritte]", count: 0
    get app_participation_path
    assert_select "a[href=?]", payment_app_participation_path, text: "Differenz bezahlen"
    assert_select ".drawer-side a[href=?] [role=img]", app_participation_path
    assert_select "a", text: "Mitgliedschaft erhöhen", count: 0
    assert_no_difference "ParticipationUpgrade.count" do
      patch app_participation_path(setup: 0), params: { participation: { category: "leist_member" } }
    end
    patch admin_participation_upgrade_path(upgrade)
    assert_redirected_to root_path
    assert upgrade.reload.pending?
    sign_in users(:admin)
    get admin_user_path(participation.user)
    assert_select "button", text: "Differenzzahlung bestätigen"
    patch admin_participation_path(participation), params: { participation: { payment_status: "pending" } }
    assert_response :unprocessable_entity
    assert participation.reload.paid?
    patch admin_participation_upgrade_path(upgrade)
    assert_redirected_to admin_user_path(participation.user)
    assert_equal "leist_member", participation.reload.category
    assert upgrade.reload.paid?
    sign_in users(:member)
    get edit_app_participation_path(setup: 0)
    assert_redirected_to app_participation_path
    assert_no_difference "ParticipationUpgrade.count" do
      patch app_participation_path(setup: 0), params: { participation: { category: "non_leist_member" } }
    end
    assert_response :unprocessable_entity
    assert_equal "leist_member", participation.reload.category
    get edit_app_mystore_path
    assert_response :success
  end

  test "listed paid tiers cannot change or generate another payment" do
    Participation::LISTED_CATEGORIES.zip([ users(:member), users(:other) ]).each do |category, user|
      participation = participation_for(user, category: category, paid: true)
      sign_in user
      get app_participation_path
      assert_select "a[href=?]", edit_app_participation_path(setup: 0), count: 0
      get edit_app_participation_path(setup: 0)
      assert_redirected_to app_participation_path
      get payment_app_participation_path
      assert_redirected_to app_participation_path
      Participation::CATEGORIES.each_key do |target|
        assert_no_difference "ParticipationUpgrade.count" do
          patch app_participation_path(setup: 0), params: { participation: { category: target } }
        end
        assert_response :unprocessable_entity
        assert_equal category, participation.reload.category
        assert_equal 0, participation.amount_due_cents
      end
    end
  end

  test "an old pending upgrade between listed tiers cannot be requested or paid" do
    participation = participation_for(paid: true)
    upgrade = participation.upgrades.build(category: "non_leist_member", previous_category: "leist_member",
      previous_amount_cents: 20_000, amount_cents: 25_000, difference_cents: 5_000)
    upgrade.save!(validate: false)
    token = Rails.application.message_verifier("dummy-membership-payment").generate({
      "participation_id" => participation.id, "upgrade_id" => upgrade.id, "amount_cents" => 5_000
    }, expires_in: 30.minutes)

    sign_in users(:member)
    assert_nil participation.pending_upgrade
    assert_not participation.payment_due?
    get app_participation_path
    assert_select "a[href=?]", payment_app_participation_path, count: 0
    get edit_app_participation_path(setup: 0)
    assert_redirected_to app_participation_path
    get app_test_payment_path
    assert_redirected_to app_participation_path
    patch app_participation_path(setup: 0), params: { participation: { category: "non_leist_member" } }
    assert_response :unprocessable_entity
    post app_test_payment_path, params: { token: token }
    assert_response :conflict

    sign_in users(:admin)
    get admin_user_path(participation.user)
    assert_select "button", text: "Differenzzahlung bestätigen", count: 0
    patch admin_participation_upgrade_path(upgrade)
    assert_response :unprocessable_entity
    assert upgrade.reload.pending?
    assert_equal "leist_member", participation.reload.category
    assert_equal 20_000, participation.amount_cents
  end

  test "selection succeeds when the initializer has not populated custom configuration" do
    previous = Rails.configuration.x.participation_year
    Rails.configuration.x.participation_year = ActiveSupport::OrderedOptions.new
    sign_in users(:member)
    get edit_app_participation_path
    assert_response :success
    assert_select "body[data-layout=setup]"
    assert_select ".drawer-side", count: 0
    assert_select "h1", text: "Ihre Mitgliedschaft #{Date.current.year}"
    assert_select "input[type=radio]", count: 3
    assert_select "[data-setup-header]"
    assert_select "main[data-setup-scroll] nav[aria-label=Anmeldeschritte]"
    assert_select "main .app-bottombar", count: 0
    assert_select ".app-bottombar button[form=participation-form]", text: "Weiter zum Zahlungsstatus"
    assert_no_match(/\{\}/, Nokogiri::HTML(response.body).at_css("main").text)

    patch app_participation_path, params: { participation: { category: "leist_member" } }, headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
    assert_redirected_to payment_app_participation_path(setup: 1)
    assert_equal Date.current.year, users(:member).current_participation.year
    follow_redirect!
    assert_select "body[data-layout=payment]"
    assert_select "nav[aria-label=Anmeldeschritte]", count: 0
    assert_select ".app-bottombar a[href=?]", app_print_order_path(setup: 1)
    assert_select "[data-controller=flash], .toast", count: 0
  ensure
    Rails.configuration.x.participation_year = previous
  end

  test "setup stays separate through print validation and business details" do
    sign_in users(:member)
    patch app_print_order_path(setup: 1), params: { quantities: { print_products(:posters).id => "-1" } }
    assert_response :unprocessable_entity
    assert_select "body[data-layout=setup]"
    assert_select "form[action=?]", app_print_order_path(setup: 1)
    assert_select ".app-bottombar button[form=print-order-form]"
    patch app_print_order_path(setup: 1), params: { quantities: { print_products(:posters).id => "2" } }
    assert_redirected_to app_print_order_path(setup: 1)
    follow_redirect!
    assert_select "body[data-layout=setup]"
    assert_select "select", count: 0
    assert_select ".app-bottombar a[href=?]", edit_app_mystore_path(setup: 1)
    get edit_app_mystore_path(setup: 1)
    assert_select "body[data-layout=setup]"
    assert_select "form[action=?]", app_mystore_path(setup: 1)
    assert_select "button", text: "Angaben speichern und zum Dashboard"
    assert_select ".app-bottombar button[form=business-form]"
    patch app_mystore_path(setup: 1), params: { business: { business_name: "" } }
    assert_response :unprocessable_entity
    assert_select "body[data-layout=setup]"
    patch app_mystore_path(setup: 1), params: { business: { business_name: "Mein Geschäft" } }
    assert_redirected_to app_mystore_path
    follow_redirect!
    assert_select ".drawer-side"
    assert_select "body[data-layout=setup]", count: 0
  end

  test "dashboard print editing does not show setup steps or redirect to business setup" do
    sign_in users(:member)
    get edit_app_print_order_path
    assert_select ".drawer-side"
    assert_select "nav[aria-label=Anmeldeschritte]", count: 0
    assert_select "a", text: "Später auswählen", count: 0
  end

  test "print navigation opens a summary with editing in the same dashboard layout" do
    sign_in users(:member)
    get app_print_order_path
    assert_response :success
    assert_select ".drawer-side a[href=?]", app_print_order_path, count: 1
    assert_select ".drawer-side a[href=?]", edit_app_print_order_path, count: 0
    assert_select "select", count: 0
    assert_select ".app-topbar a[href=?]", edit_app_print_order_path, count: 0
    assert_select "section[aria-labelledby=print-order-summary-heading] + div a[href=?]", edit_app_print_order_path, text: "Bestellung bearbeiten"
    get edit_app_print_order_path
    assert_response :success
    assert_select ".drawer-side a.menu-active[href=?]", app_print_order_path
    assert_select "body[data-layout=setup]", count: 0
    assert_select ".app-bottombar a[href=?]", app_print_order_path, text: "Abbrechen"
  end

  test "orders remain editable through the deadline but cannot be changed afterwards" do
    deadline = Date.new(EventConfiguration.year, 11, 15)
    PrintDistribution.create!(year: EventConfiguration.year, order_deadline_on: deadline)
    sign_in users(:member)
    travel_to deadline.in_time_zone("Europe/Zurich").end_of_day do
      get edit_app_print_order_path
      assert_response :success
      patch app_print_order_path, params: { quantities: { print_products(:posters).id => "2" } }
      assert_redirected_to app_print_order_path
    end
    order = users(:member).print_orders.for_year.sole
    travel_to (deadline + 1).in_time_zone("Europe/Zurich").beginning_of_day do
      get app_print_order_path
      assert_response :success
      assert_select "[data-order-deadline]", text: /kann nicht mehr geändert werden/
      assert_select "a[href=?]", edit_app_print_order_path, count: 0
      get edit_app_print_order_path
      assert_redirected_to app_print_order_path
      patch app_print_order_path, params: { quantities: { print_products(:posters).id => "0" } }
      assert_redirected_to app_print_order_path
      assert_equal 2, order.reload.items.sole.quantity
      patch app_print_order_path(setup: 1), params: { quantities: { print_products(:posters).id => "3" } }
      assert_redirected_to app_print_order_path(setup: 1)
      follow_redirect!
      assert_select ".app-bottombar a[href=?]", edit_app_mystore_path(setup: 1)
      assert_select "a[href=?]", edit_app_print_order_path(setup: 1), count: 0
      sign_in users(:other)
      assert_no_difference "PrintOrder.count" do
        patch app_print_order_path, params: { quantities: { print_products(:posters).id => "1" } }
      end
      assert_redirected_to app_print_order_path
      sign_in users(:admin)
      patch admin_print_order_path(order), params: { quantities: { print_products(:posters).id => "3" } }
      assert_redirected_to admin_print_order_path(order)
      assert_equal 3, order.reload.items.sole.quantity
    end
  end

  test "payment and approval warnings stay in navigation and their own detail pages" do
    participation = participation_for
    businesses(:member).update!(status: :pending)
    sign_in users(:member)
    [ app_print_order_path, edit_app_print_order_path, edit_app_mystore_path ].each do |path|
      get path
      assert_response :success
      assert_select ".alert", count: 0
      assert_select "section[aria-label=Freigabestatus]", count: 0
      assert_select ".drawer-side a[href=?] [aria-label=?]", app_participation_path, "Teilnahme oder Zahlung noch offen"
      assert_select ".drawer-side a[href=?] [aria-label=?]", app_mystore_path, "Geschäft noch nicht freigegeben"
    end
    get edit_user_registration_path
    assert_response :success
    assert_select ".alert", count: 0
    get app_participation_path
    assert_select "p", text: /Zahlung ist noch offen/
    assert_select "section[aria-label=Freigabestatus]", count: 0
    get app_mystore_path
    assert_select "section[aria-label=Freigabestatus]", text: /Freigabe noch ausstehend/
    assert_select ".alert", count: 0
    participation.mark_paid!
    businesses(:member).update!(status: :confirmed)
    get app_print_order_path
    assert_select ".drawer-side [role=img]", count: 0
  end

  test "member print quantities use dropdowns from one to ten with an optional unselected state" do
    sign_in users(:member)
    get edit_app_print_order_path(setup: 1)
    assert_select "input[type=number]", count: 0
    assert_select "select[name=?] option", "quantities[#{print_products(:posters).id}]" do |options|
      assert_equal (0..10).map(&:to_s), options.map { |option| option["value"] }
    end
    assert_select "option[value='0']", text: "Keine"
    assert_no_match(/gratis/i, Nokogiri::HTML(response.body).at_css("main").text)
    assert_select ".alert-info", count: 0

    patch app_print_order_path, params: { quantities: { print_products(:posters).id => "10" } }
    assert_redirected_to app_print_order_path
    order = users(:member).print_orders.for_year.sole
    assert_equal 10, order.items.sole.quantity
    patch app_print_order_path(setup: 1), params: { quantities: { print_products(:posters).id => "11" } }
    assert_response :unprocessable_entity
    assert_select ".alert-error", text: /zwischen 1 und 10/
    assert_equal 10, order.reload.items.sole.quantity
    patch app_print_order_path, params: { quantities: { print_products(:posters).id => "0" } }
    assert_redirected_to app_print_order_path
    assert_empty order.reload.items
  end

  test "store routes require authentication" do
    [ app_root_path, app_participation_path, payment_app_participation_path, app_print_order_path, edit_app_mystore_path ].each do |path|
      get path
      assert_redirected_to new_user_session_path
    end
  end

  test "returning incomplete user can log in and edit their business" do
    post user_session_path, params: { user: { email: users(:member).email, password: "password123" } }
    assert_redirected_to app_participation_path
    get edit_app_mystore_path
    assert_response :success
    assert_select ".alert", count: 0
    assert_select ".drawer-side a[href=?] [aria-label=?]", app_participation_path, "Teilnahme oder Zahlung noch offen"
  end

  test "user selects category but cannot submit payment or another user or year" do
    sign_in users(:member)
    patch app_participation_path, params: { participation: { category: "non_leist_member", payment_status: "paid", amount_cents: 1, user_id: users(:other).id, year: 2040 } }
    assert_redirected_to payment_app_participation_path(setup: 1)
    participation = users(:member).current_participation
    assert participation.pending?
    assert_equal 25_000, participation.amount_cents
    assert_equal EventConfiguration.year, participation.year
    assert_nil users(:other).current_participation
    follow_redirect!
    assert_select "a[href=?]", app_test_payment_path(setup: 1), text: "Testzahlung öffnen"
    assert_select "a[href=?]", app_print_order_path(setup: 1)
  end

  test "pending user can change category but a paid membership only offers upgrades" do
    participation = participation_for
    sign_in users(:member)
    get edit_app_participation_path(setup: 0)
    assert_response :success
    assert_select ".drawer-side a.menu-active[href=?]", app_participation_path
    assert_select "nav[aria-label=Anmeldeschritte]", count: 0
    assert_select "input[type=radio][value=leist_member][checked]"
    assert_select "form[action=?]", app_participation_path(setup: 0)
    patch app_participation_path(setup: 0), params: { participation: { category: "invalid" } }
    assert_response :unprocessable_entity
    assert_select ".drawer-side"
    assert_select "nav[aria-label=Anmeldeschritte]", count: 0
    patch app_participation_path(setup: 0), params: { participation: { category: "no_listing" } }
    assert_redirected_to app_participation_path
    assert_equal "no_listing", participation.reload.category
    assert_equal 10_000, participation.amount_cents
    participation.mark_paid!
    get edit_app_participation_path(setup: 0)
    assert_response :success
    assert_select "input[type=radio]", count: 2
    assert_select "input[value=no_listing]", count: 0
    patch app_participation_path(setup: 0), params: { participation: { category: "no_listing" } }
    assert_response :unprocessable_entity
    assert_equal "no_listing", participation.reload.category
    get app_participation_path
    assert_response :success
    assert_select "input[type=radio]", count: 0
    assert_select ".alert", text: /Teilnahme .* ist noch nicht abgeschlossen/, count: 0
  end

  test "missing or invalid category is handled without creating participation" do
    sign_in users(:member)
    get payment_app_participation_path
    assert_redirected_to edit_app_participation_path
    patch app_participation_path, params: { participation: { category: "unknown" } }
    assert_response :unprocessable_entity
    assert_nil users(:member).current_participation
  end

  test "invalid category on an existing selection renders errors without altering its snapshot" do
    participation = participation_for
    sign_in users(:member)
    patch app_participation_path, params: { participation: { category: "unknown" } }
    assert_response :unprocessable_entity
    assert_equal "leist_member", participation.reload.category
    assert_equal 20_000, participation.amount_cents
  end

  test "account editing remains available without completed participation" do
    sign_in users(:member)
    get edit_user_registration_path
    assert_response :success
    assert_select ".drawer-side a.menu-active[href=?]", edit_user_registration_path, text: "Kontoeinstellungen"
    assert_select "h1", text: "Kontoeinstellungen"
    assert_select ".app-bottombar button[form=account-settings-form]", text: "Änderungen speichern"
    assert_select "form#account-settings-form input[name='user[current_password]'][required]"
    assert_select "button[data-turbo-confirm]", text: "Konto löschen"
    patch user_registration_path, params: { user: { name: "Neuer Kontakt", phone: "0310000000", current_password: "password123", role: 2 } }
    assert_redirected_to edit_user_registration_path
    assert_equal "Neuer Kontakt", users(:member).reload.name
    assert users(:member).user?
  end

  test "account settings preserve password verification and render invalid updates in the dashboard" do
    sign_in users(:member)
    original_name = users(:member).name
    patch user_registration_path, params: { user: { name: "Nicht speichern", current_password: "incorrect" } }
    assert_response :unprocessable_entity
    assert_select ".drawer-side a.menu-active[href=?]", edit_user_registration_path
    assert_select "#error_explanation"
    assert_equal original_name, users(:member).reload.name
    patch user_registration_path, params: { user: { password: "new-password123", password_confirmation: "new-password123", current_password: "password123" } }
    assert_redirected_to edit_user_registration_path
    assert users(:member).reload.valid_password?("new-password123")
    follow_redirect!
    assert_response :success
    assert_select "input[type=password][value]", count: 0
  end

  test "settings email changes still require confirmation and signup retains its own layout" do
    sign_in users(:member)
    original_email = users(:member).email
    patch user_registration_path, params: { user: { email: "updated@example.com", current_password: "password123" } }
    assert_redirected_to edit_user_registration_path
    assert_equal original_email, users(:member).reload.email
    assert_equal "updated@example.com", users(:member).unconfirmed_email
    follow_redirect!
    assert_select "p", text: /Die Bestätigung für updated@example.com steht noch aus/
    assert_select ".drawer-side"
    sign_out users(:member)
    get new_user_registration_path
    assert_response :success
    assert_select ".drawer-side", count: 0
  end

  test "business uses one navigation entry and a content edit action without a badge" do
    sign_in users(:member)
    get app_mystore_path
    assert_response :success
    assert_select ".drawer-side a[href=?]", edit_app_mystore_path, count: 0
    assert_select ".drawer-side a.menu-active[href=?]", app_mystore_path, count: 1
    assert_select ".drawer-side a[href=?]", app_participation_path, text: "Mitgliedschaft"
    assert_select ".app-topbar a[href=?]", edit_app_mystore_path, count: 0
    assert_select "header .badge", count: 0
    assert_select "a[href=?]", edit_app_mystore_path, text: /Informationen bearbeiten/
    edit_link = Nokogiri::HTML(response.body).at_css("a[href='#{edit_app_mystore_path}']")
    assert_equal "Geschäftsinformationen", edit_link.at_xpath("following::h2[1]").text.strip
    get edit_app_mystore_path
    assert_response :success
    assert_select ".drawer-side a.menu-active[href=?]", app_mystore_path
    assert_select "header .badge", count: 0
  end

  test "no listing membership replaces approval information and blocks all business edits" do
    participation = participation_for(category: "no_listing")
    business = businesses(:member)
    sign_in users(:member)
    %w[pending rejected confirmed].each do |status|
      business.update!(status: status)
      get app_mystore_path
      assert_response :success
      assert_select "#no-listing-heading", text: "Ihre Mitgliedschaft beinhaltet keinen Website-Eintrag"
      assert_select "section[aria-label=Freigabestatus]", count: 0
      assert_select "a[href=?]", edit_app_mystore_path, count: 0
      assert_select ".drawer-side a[href=?] [role=img]", app_mystore_path, count: 0
      assert_select "a[href=?]", edit_app_participation_path(setup: 0), text: "Mitgliedschaft ändern"
    end
    File.open(Rails.root.join("app/assets/images/placeholder.png")) do |image|
      business.main_image.attach(io: image, filename: "shop.png", content_type: "image/png")
    end
    [ false, true ].each do |paid|
      participation.mark_paid! if paid
      get edit_app_mystore_path(setup: 1)
      assert_redirected_to app_mystore_path
      patch app_mystore_path, params: { business: { business_name: "Nicht speichern" } }
      assert_redirected_to app_mystore_path
      assert_equal "Testgeschäft", business.reload.business_name
      delete purge_image_app_mystore_path(image: :main_image)
      assert_redirected_to app_mystore_path
      assert business.reload.main_image.attached?
    end
    get app_mystore_path
    assert_select "a[href=?]", edit_app_participation_path(setup: 0), text: "Mitgliedschaft erhöhen"
    get app_print_order_path(setup: 1)
    assert_response :success
    assert_select ".app-bottombar a[href=?]", app_mystore_path, text: "Zum Dashboard"
    assert_select "a[href=?]", edit_app_mystore_path(setup: 1), count: 0
    get edit_user_registration_path
    assert_response :success
  end

  test "no listing membership prevents business creation and upgrading restores editing" do
    users(:other).business.destroy!
    participation_for(users(:other), category: "no_listing")
    sign_in users(:other)
    get app_mystore_path
    assert_response :success
    assert_select "#no-listing-heading"
    assert_select "a[href=?]", edit_app_mystore_path, count: 0
    assert_no_difference "Business.count" do
      post app_mystore_path, params: { business: { business_name: "Nicht erstellen" } }
    end
    assert_redirected_to app_mystore_path
    patch app_participation_path(setup: 0), params: { participation: { category: "leist_member" } }
    assert_redirected_to app_participation_path
    get edit_app_mystore_path
    assert_response :success
    assert_select "form#business-form"
  end

  test "skip selection does not create or alter an order and business details remain accessible" do
    sign_in users(:member)
    get app_print_order_path(setup: 1)
    assert_response :success
    assert_select "a[href=?]", edit_app_mystore_path(setup: 1), text: "Weiter zu Geschäftsangaben"
    assert_no_difference "PrintOrder.count" do
      get edit_app_mystore_path(setup: 1)
      assert_response :success
      assert_select "body[data-layout=setup]"
    end
  end

  test "user can create then edit current order without touching another users order" do
    other_order = users(:other).print_orders.create!(year: EventConfiguration.year)
    sign_in users(:member)
    patch app_print_order_path, params: { user_id: users(:other).id, quantities: { print_products(:posters).id => "2" } }
    assert_redirected_to app_print_order_path
    assert_empty other_order.reload.items
    order = users(:member).print_orders.for_year.sole
    assert_equal 2, order.items.sole.quantity
    patch app_print_order_path, params: { quantities: { print_products(:posters).id => "4" } }
    assert_equal 4, order.reload.items.sole.quantity
    get app_print_order_path
    assert_response :success
    assert_select "[data-bundle-quantity]", text: "4"
    assert_select "h3", text: print_products(:posters).title
    assert_select "p", text: print_products(:posters).description
    assert_select "p", text: "1 Materialart · 4 Bündel insgesamt"
    assert_select "p", text: /Zuletzt aktualisiert am/
    assert_select "section[aria-labelledby=print-delivery-heading]", text: /Verteilung und Lieferung/
  end

  test "invalid quantities show errors and do not save an order" do
    sign_in users(:member)
    patch app_print_order_path, params: { quantities: { print_products(:posters).id => "-1" } }
    assert_response :unprocessable_entity
    assert_empty users(:member).reload.print_orders
  end

  test "new user can create business after skipping print selection" do
    users(:other).business.destroy!
    user = users(:other).reload
    sign_in user
    get edit_app_mystore_path
    assert_response :success
    post app_mystore_path, params: { business: { business_name: "Neues Geschäft", phone: "0311234567", address: "Bern", billing_address: "Bern", map_link: "", categories: [ "Einzelhandel" ] } }
    assert_redirected_to app_mystore_path
    assert_equal "Neues Geschäft", user.reload.business.business_name
  end
end
