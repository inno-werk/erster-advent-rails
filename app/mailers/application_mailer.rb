class ApplicationMailer < ActionMailer::Base
  default from: "Erster Advent Bern <info@erster-advent-bern.ch>"
  helper BrandingHelper
  layout "mailer"
end
