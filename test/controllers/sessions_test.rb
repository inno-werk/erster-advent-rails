require "test_helper"

class SessionsTest < ActionDispatch::IntegrationTest
  test "admin and member login share the design but use separate endpoints without registration links" do
    {
      admin_login_path => [ admin_session_path, "Admin-Login" ],
      new_user_session_path => [ user_session_path, "Melden Sie sich bei Ihrem Konto an" ]
    }.each do |path, (action, heading)|
      get path
      assert_response :success
      assert_select "h1", text: heading
      assert_select "form[action=?][method=post]", action
      assert_select "input[name='user[email]'][autocomplete=email]"
      assert_select "input[name='user[password]'][autocomplete=current-password]"
      assert_select "a[href=?]", new_user_registration_path, count: 0
      assert_select "a[href=?]", new_user_password_path
      assert_select "[role=alert]", count: 0
    end
  end

  test "failed admin login stays on the admin form for HTML and Turbo requests" do
    [ "text/html", "text/vnd.turbo-stream.html, text/html" ].each do |accept|
      post admin_session_path, params: { user: { email: users(:admin).email, password: "wrong-password" } },
        headers: { "Accept" => accept }
      assert_response :unprocessable_entity
      assert_select "h1", text: "Admin-Login"
      assert_select "[role=alert]", text: /E-Mail oder Passwort ist ungültig/
      assert_select "form[action=?]", admin_session_path
      assert_select "input[name='user[email]'][value=?]", users(:admin).email
      assert_select "input[type=password][value]", count: 0
      assert_select "a[href=?]", new_user_registration_path, count: 0
    end
    assert_equal 2, users(:admin).reload.failed_attempts
    get admin_root_path
    assert_redirected_to admin_login_path
  end

  test "regular login failures stay on the regular form and show their error" do
    post user_session_path, params: { user: { email: users(:member).email, password: "wrong-password" } }
    assert_response :unprocessable_entity
    assert_select "h1", text: "Melden Sie sich bei Ihrem Konto an"
    assert_select "[role=alert]", text: /E-Mail oder Passwort ist ungültig/
    assert_select "form[action=?]", user_session_path
    assert_select "input[type=password][value]", count: 0
  end

  test "admin login accepts administrators and superadministrators" do
    admin = users(:admin)
    get edit_app_mystore_path
    assert_redirected_to new_user_session_path
    [ 1, 2 ].each do |role|
      admin.update!(role: role)
      assert_difference -> { admin.reload.sign_in_count }, 1 do
        post admin_session_path, params: { user: { email: admin.email, password: "password123" } }
      end
      assert_redirected_to admin_root_path
      get admin_users_path
      assert_response :success
      get admin_login_path
      assert_redirected_to admin_root_path
      sign_out :user
    end
  end

  test "paid members land on the store overview after regular login" do
    participation_for(paid: true)
    post user_session_path, params: { user: { email: users(:member).email, password: "password123" } }
    assert_redirected_to app_mystore_path
    follow_redirect!
    assert_response :success
    assert_select "form#business-form", count: 0
    assert_select ".app-topbar a[href=?]", edit_app_mystore_path, text: /Informationen bearbeiten/
  end

  test "member credentials cannot establish a session through admin login" do
    post admin_session_path, params: { user: { email: users(:member).email, password: "password123" } }
    assert_response :unprocessable_entity
    assert_select "h1", text: "Admin-Login"
    assert_select "[role=alert]", text: "Dieses Konto hat keinen Zugang zum Adminbereich."
    assert_select "form[action=?]", admin_session_path
    assert_select "input[type=password][value]", count: 0
    get app_participation_path
    assert_redirected_to new_user_session_path
    get admin_root_path
    assert_redirected_to admin_login_path
  end

  test "locked and unconfirmed administrators remain on admin login" do
    admin = users(:admin)
    admin.update_columns(locked_at: Time.current, failed_attempts: 20)
    post admin_session_path, params: { user: { email: admin.email, password: "password123" } }
    assert_response :unprocessable_entity
    assert_select "h1", text: "Admin-Login"
    assert_select "[role=alert]", text: /gesperrt/
    admin.update_columns(locked_at: nil, failed_attempts: 0, confirmed_at: nil)
    post admin_session_path, params: { user: { email: admin.email, password: "password123" } }
    assert_redirected_to admin_login_path
    follow_redirect!
    assert_response :success
    assert_select "h1", text: "Admin-Login"
    assert_select "[role=alert]", text: /bestätigen/
    get admin_root_path
    assert_redirected_to admin_login_path
  end

  test "signed in members keep their session and cannot access admin pages" do
    sign_in users(:member)
    get admin_login_path
    assert_redirected_to app_participation_path
    get admin_users_path
    assert_redirected_to root_path
    get app_participation_path
    assert_response :success
  end

  test "registration remains reachable by direct link but is not advertised on account recovery screens" do
    [ new_user_password_path, new_user_confirmation_path, new_user_unlock_path ].each do |path|
      get path
      assert_response :success
      assert_select "a[href=?]", new_user_registration_path, count: 0
    end
    get new_user_registration_path
    assert_response :success
    assert_select "form[action=?]", user_registration_path
    assert_select "input[type=submit][value=Registrieren]"
  end

  test "admin login requires a valid CSRF token" do
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    get admin_login_path
    token = css_select("form input[name=authenticity_token]").sole["value"]
    credentials = { email: users(:admin).email, password: "password123" }
    post admin_session_path, params: { user: credentials }
    assert_response :unprocessable_entity
    get admin_root_path
    assert_redirected_to admin_login_path
    post admin_session_path, params: { authenticity_token: token, user: credentials }
    assert_redirected_to admin_root_path
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end
end
