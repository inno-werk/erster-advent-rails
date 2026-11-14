require "net/http"

# Server-side verification of Cloudflare Turnstile tokens.
#
# Turnstile is enabled only when both TURNSTILE_SITE_KEY and
# TURNSTILE_SECRET_KEY are set. `verify` returns:
# - :success      the token is valid;
# - :failure      the token is missing or rejected by Cloudflare;
# - :unavailable  Cloudflare could not be reached or reported an internal or
#                 configuration error. Callers fail open; the other spam checks
#                 still apply.
class TurnstileVerifier
  ENDPOINT = URI("https://challenges.cloudflare.com/turnstile/v0/siteverify").freeze
  RESPONSE_PARAM = "cf-turnstile-response".freeze
  MAX_TOKEN_LENGTH = 2048
  CONFIGURATION_ERROR_CODES = %w[missing-input-secret invalid-input-secret].freeze
  NETWORK_ERRORS = [
    Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout, Timeout::Error,
    EOFError, IOError, SocketError, SystemCallError, OpenSSL::SSL::SSLError,
    Net::HTTPBadResponse, Net::ProtocolError, JSON::ParserError
  ].freeze

  def self.enabled?
    site_key.present? && secret_key.present?
  end

  def self.site_key
    ENV["TURNSTILE_SITE_KEY"].to_s.strip.presence
  end

  def self.secret_key
    ENV["TURNSTILE_SECRET_KEY"].to_s.strip.presence
  end

  def self.verify(token:, remote_ip: nil)
    return :failure unless token.is_a?(String) && token.present? && token.length <= MAX_TOKEN_LENGTH

    response = Net::HTTP.start(ENDPOINT.host, ENDPOINT.port, use_ssl: true,
      open_timeout: 2, ssl_timeout: 2, read_timeout: 3, write_timeout: 3) do |http|
      request = Net::HTTP::Post.new(ENDPOINT)
      request.set_form_data({ "secret" => secret_key, "response" => token, "remoteip" => remote_ip }.compact)
      http.request(request)
    end
    return unavailable("http_#{response.code}") unless response.is_a?(Net::HTTPSuccess)

    body = JSON.parse(response.body.to_s)
    return unavailable("unexpected_body") unless body.is_a?(Hash)
    return :success if body["success"] == true

    codes = Array(body["error-codes"]).map(&:to_s)
    if codes.intersect?(CONFIGURATION_ERROR_CODES)
      Rails.logger.error("[turnstile] verification skipped: configuration error (#{codes.join(", ")})")
      return :unavailable
    end
    return unavailable("internal-error") if codes.include?("internal-error")

    :failure
  rescue *NETWORK_ERRORS => error
    unavailable(error.class.name)
  end

  def self.unavailable(reason)
    Rails.logger.warn("[turnstile] verification unavailable, failing open (#{reason})")
    :unavailable
  end
  private_class_method :unavailable
end
