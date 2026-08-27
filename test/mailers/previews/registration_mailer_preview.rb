class RegistrationMailerPreview < ActionMailer::Preview
  def new_registration
    RegistrationMailer.new_registration(User.new(id: 0, email: "beispiel@example.com", name: "Anna Beispiel", business_name: "Beispielgeschäft Bern"))
  end
end
