class ApplicationController < ActionController::Base
  include Pagy::Backend
  include AccountEmailPreviews
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  before_action :set_locale

  def set_locale
  locale = params[:locale] ||
           extract_locale_from_accept_language_header ||
           I18n.default_locale
    I18n.locale = I18n.available_locales.include?(locale&.to_sym) ? locale : I18n.default_locale
  end

  def default_url_options
    { locale: I18n.locale == I18n.default_locale ? nil : I18n.locale }
  end

  def extract_locale_from_accept_language_header
    request.env["HTTP_ACCEPT_LANGUAGE"]
      &.scan(/[a-z]{2}/)&.find { |l| %w[en de it fr].include?(l) }
  end
end
