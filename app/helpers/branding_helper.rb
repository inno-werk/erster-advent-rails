module BrandingHelper
  # Overrides daisyUI's `--color-primary` at runtime, so every `primary`
  # utility in the theme (and the `--color-primary-dark` derived from it)
  # follows the brand colour the admin picked.
  #
  # daisyUI declares the theme on `[data-theme=light]`; `html[data-theme]`
  # outranks that, so this wins regardless of stylesheet order.
  def brand_color_style_tag
    css = "html[data-theme]{--color-primary:#{brand_color};}"
    tag.style(css.html_safe, **brand_style_options)
  end

  # Always a syntactically valid hex colour, so it can never break out of the
  # CSS declaration it is interpolated into.
  #
  # Memoized per request rather than cached: the lookup is a single row, and a
  # shared cache would go stale per process the moment an admin changes it.
  def brand_color
    @brand_color ||= begin
      color = SiteSetting.brand_color
      color.to_s.match?(SiteSetting::HEX_COLOR) ? color : SiteSetting::DEFAULT_BRAND_COLOR
    end
  end

  private

  def brand_style_options
    return {} unless respond_to?(:request) && request

    { nonce: content_security_policy_nonce }
  end
end
