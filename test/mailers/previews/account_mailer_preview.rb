class AccountMailerPreview < ActionMailer::Preview
  def confirmation_instructions
    AccountMailer.confirmation_instructions(example_user, "vorschau-kein-gueltiger-token")
  end

  def reset_password_instructions
    AccountMailer.reset_password_instructions(example_user, "vorschau-kein-gueltiger-token")
  end

  private

  def example_user
    User.new(email: "beispiel@example.com", name: "Anna Beispiel", business_name: "Beispielgeschäft Bern")
  end
end
