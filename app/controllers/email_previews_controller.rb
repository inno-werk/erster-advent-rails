class EmailPreviewsController < ApplicationController
  layout false
  before_action :prevent_caching

  def show
    return head :not_found unless account_email_preview_owner

    @preview = AccountEmailPreview.read(session[:account_email_preview_key])
    return head :not_found unless @preview

    # Use this deployment for account links, even if its mail host differs.
    document = Nokogiri::HTML(@preview.fetch("html"))
    document.css("a[href]").each do |link|
      original_url = link["href"]
      uri = URI.parse(original_url)
      if uri.path&.match?(%r{\A/users/(confirmation|password/edit|unlock)\z}) && %w[http https].include?(uri.scheme)
        link["href"] = "#{request.base_url}#{uri.request_uri}"
        link.content = link["href"] if link.text == original_url
      end
      link["target"] = "_blank"
      link["rel"] = "noopener noreferrer"
    end
    @email_html = document.to_html
  end

  private

  def prevent_caching
    response.headers["Cache-Control"] = "no-store, private"
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["X-Robots-Tag"] = "noindex, nofollow"
    response.headers["Content-Security-Policy"] = "default-src 'none'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; frame-src 'self' about:; frame-ancestors 'self'; base-uri 'none'; form-action 'none'"
  end
end
