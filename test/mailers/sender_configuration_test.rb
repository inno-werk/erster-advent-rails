require "test_helper"

class SenderConfigurationTest < ActionMailer::TestCase
  setup do
    @original_smtp_from = ENV.delete("SMTP_FROM")
  end

  teardown do
    ENV["SMTP_FROM"] = @original_smtp_from
  end

  test "all emails retain the default sender when SMTP_FROM is unset or blank" do
    [ nil, "", "  " ].each do |value|
      ENV["SMTP_FROM"] = value
      messages.each do |mail|
        assert_equal [ "info@erster-advent-bern.ch" ], mail.from
      end
    end
  end

  test "SMTP_FROM applies to admin notifications and all account emails" do
    ENV["SMTP_FROM"] = "Erster Advent Test <sender@gmail.com>"
    messages.each do |mail|
      assert_equal [ "sender@gmail.com" ], mail.from
    end
    assert_equal [ "info@erster-advent-bern.ch" ], RegistrationMailer.new_registration(users(:member)).to
    assert_equal [ users(:member).email ], AccountMailer.confirmation_instructions(users(:member), "test-token").to
  end

  private

  def messages
    [
      RegistrationMailer.new_registration(users(:member)),
      AccountMailer.confirmation_instructions(users(:member), "test-token"),
      AccountMailer.reset_password_instructions(users(:member), "test-token"),
      AccountMailer.unlock_instructions(users(:member), "test-token"),
      AccountMailer.email_changed(users(:member)),
      AccountMailer.password_change(users(:member))
    ]
  end
end
