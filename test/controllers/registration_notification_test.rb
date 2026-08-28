require "test_helper"

class RegistrationNotificationTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @original_prod_send = ENV["PROD_SEND"]
    ENV["PROD_SEND"] = "true"
  end

  teardown do
    ENV["PROD_SEND"] = @original_prod_send
  end

  test "initial registration queues exactly one admin notification" do
    ENV["PROD_SEND"] = "true"
    assert_difference [ "User.count", "Business.count" ] do
      assert_enqueued_email_with RegistrationMailer, :new_registration, args: ->(args) { args.first.email == "new-registration@example.com" } do
        post user_registration_path, params: { user: {
          business_name: "Neu GmbH", email: "new-registration@example.com", address: "Bern",
          name: "Neue Person", phone: "031 000 00 00", password: "password123"
        } }
      end
    end
    user = User.find_by!(email: "new-registration@example.com")
    business = user.business
    assert_equal "Neu GmbH", business.business_name
    assert_equal "031 000 00 00", business.phone
    assert_equal "Bern", business.address
    assert_equal "Bern", business.billing_address
    assert_equal user.email, business.email
    assert_equal "Neue Person", business.contact_name
    assert business.pending?
    assert_not business.publicly_visible?
    assert_not user.confirmed?
    assert_no_difference "Business.count" do
      user.confirm
      sign_in user
      get edit_app_mystore_path
      assert_response :success
      assert_select "input[name='business[business_name]'][value='Neu GmbH']"
      assert_select "button", text: "Geschäft anlegen", count: 0
    end
  end

  test "failed registration and later state changes do not notify admin" do
    ENV["PROD_SEND"] = "true"
    assert_no_difference [ "User.count", "Business.count" ] do
      assert_no_enqueued_emails do
        post user_registration_path, params: { user: { email: "invalid", password: "short" } }
      end
    end
    assert_no_enqueued_emails do
      participation = participation_for
      participation.mark_paid!
      businesses(:member).update!(status: :pending)
    end
  end

  test "invalid business details reject the entire registration without an orphan account" do
    ENV["PROD_SEND"] = "true"
    assert_no_difference [ "User.count", "Business.count" ] do
      assert_no_enqueued_emails do
        post user_registration_path, params: { user: {
          business_name: "Unvollständig", email: "incomplete@example.com", address: "Bern",
          name: "Neue Person", phone: "", password: "password123"
        } }
        assert_response :unprocessable_entity
      end
    end
  end

  test "notification addresses info mailbox and identifies the user" do
    ENV["PROD_SEND"] = "true"
    mail = RegistrationMailer.new_registration(users(:member))
    assert_emails 1 do
      mail.deliver_now
    end
    assert_equal [ "info@erster-advent-bern.ch" ], mail.to
    assert_equal [ "info@erster-advent-bern.ch" ], mail.from
    assert_match users(:member).email, mail.subject
    assert_match users(:member).email, mail.text_part.body.to_s
    assert_match admin_user_url(id: users(:member).id, locale: nil, host: "example.com"), mail.text_part.body.to_s
    html = Nokogiri::HTML(mail.html_part.body.decoded)
    assert html.at_css("body[data-mail-layout=branded]")
    assert_equal "Ein neues Geschäft hat sich registriert", html.at_css("h1").text
    assert html.css("a").any? { |link| link.text == "Registrierung ansehen" }
  end

  test "registration sends no emails unless delivery is explicitly enabled" do
    [ nil, "false", "", "1", "invalid" ].each_with_index do |value, index|
      ENV["PROD_SEND"] = value
      email = "notifications-disabled-#{index}@example.com"
      assert_difference [ "User.count", "Business.count" ] do
        assert_no_enqueued_emails do
          assert_no_emails do
            post user_registration_path, params: { user: {
              business_name: "Neu GmbH", email: email, address: "Bern",
              name: "Neue Person", phone: "031 000 00 00", password: "password123"
            } }
          end
        end
      end
      assert_no_emails { RegistrationMailer.new_registration(User.find_by!(email: email)).deliver_now }
    end
  end

  test "queued admin notifications are not delivered after the flag is disabled" do
    ENV["PROD_SEND"] = "true"
    RegistrationMailer.new_registration(users(:member)).deliver_later
    ENV["PROD_SEND"] = "false"
    assert_no_emails { perform_enqueued_jobs }
  end

  test "Devise password reset uses the shared email design and retains its token link" do
    assert_emails 1 do
      users(:member).send_reset_password_instructions
    end
    mail = ActionMailer::Base.deliveries.last
    html = Nokogiri::HTML((mail.html_part || mail).body.decoded)
    assert html.at_css("body[data-mail-layout=branded]")
    assert_equal "Ein neues Passwort für Ihr Konto", html.at_css("h1").text
    link = html.css("a").find { |element| element.text == "Neues Passwort festlegen" }
    assert_match %r{/users/password/edit\?reset_password_token=}, link["href"]
  end

  test "all account emails render the branded layout and valid confirmation and unlock links" do
    [ :confirmation_instructions, :unlock_instructions, :email_changed, :password_change ].each do |action|
      args = [ :confirmation_instructions, :unlock_instructions ].include?(action) ? [ users(:member), "test-token" ] : [ users(:member) ]
      mail = AccountMailer.public_send(action, *args)
      html = Nokogiri::HTML((mail.html_part || mail).body.decoded)
      assert html.at_css("body[data-mail-layout=branded]"), action
      assert html.at_css("h1"), action
      if action == :confirmation_instructions
        assert html.css("a").any? { |link| link["href"].include?("/users/confirmation?confirmation_token=test-token") }
      elsif action == :unlock_instructions
        assert html.css("a").any? { |link| link["href"].include?("/users/unlock?unlock_token=test-token") }
      end
    end
  end
end
