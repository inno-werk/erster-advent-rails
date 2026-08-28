class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV["SMTP_FROM"].presence || "Erster Advent Bern <info@erster-advent-bern.ch>" }
  helper BrandingHelper
  layout "mailer"
end
