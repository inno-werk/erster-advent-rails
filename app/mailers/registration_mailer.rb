class RegistrationMailer < ApplicationMailer
  def new_registration(user)
    @user = user
    mail(to: "info@erster-advent-bern.ch", from: "info@erster-advent-bern.ch", subject: "Neue Registrierung: #{@user.email}")
  end
end
