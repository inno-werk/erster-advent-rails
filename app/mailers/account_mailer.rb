# Keep Devise's token generation and delivery behavior, with our shared design.
class AccountMailer < Devise::Mailer
  helper BrandingHelper
  layout "mailer"
end
