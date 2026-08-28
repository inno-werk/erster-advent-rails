# Keep Devise's token generation and delivery behavior, with our shared design.
class AccountMailer < Devise::Mailer
  before_deliver { throw :abort unless EmailDelivery.enabled? }
  helper BrandingHelper
  layout "mailer"
end
