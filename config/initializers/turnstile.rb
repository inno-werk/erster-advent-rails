Rails.application.config.after_initialize do
  if Rails.env.production? && !TurnstileVerifier.enabled?
    Rails.logger.warn("[turnstile] disabled: TURNSTILE_SITE_KEY/TURNSTILE_SECRET_KEY not set")
  end
end
