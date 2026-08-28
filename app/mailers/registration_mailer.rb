class RegistrationMailer < ApplicationMailer
  before_deliver { throw :abort unless self.class.notifications_enabled? }

  def self.notifications_enabled?
    ENV.fetch("SEND_PROD_EMAILS", "false") == "true"
  end

  def new_registration(user)
    @user = user
    mail(to: "info@erster-advent-bern.ch", from: "info@erster-advent-bern.ch", subject: "Neue Registrierung: #{@user.email}")
  end
end
