require "test_helper"
require "minitest/mock"

class TurnstileVerifierTest < ActiveSupport::TestCase
  FakeHttp = Struct.new(:response, :requests) do
    def request(request)
      requests << request
      raise response if response.is_a?(Exception) || (response.is_a?(Class) && response <= Exception)

      response
    end
  end

  setup do
    @original_env = ENV.to_h.slice("TURNSTILE_SITE_KEY", "TURNSTILE_SECRET_KEY")
    ENV["TURNSTILE_SITE_KEY"] = "site-key"
    ENV["TURNSTILE_SECRET_KEY"] = "secret-key"
  end

  teardown do
    %w[TURNSTILE_SITE_KEY TURNSTILE_SECRET_KEY].each { |key| ENV[key] = @original_env[key] }
  end

  test "enabled only when both keys are present" do
    assert TurnstileVerifier.enabled?
    ENV["TURNSTILE_SECRET_KEY"] = " "
    assert_not TurnstileVerifier.enabled?
    ENV["TURNSTILE_SECRET_KEY"] = "secret-key"
    ENV.delete("TURNSTILE_SITE_KEY")
    assert_not TurnstileVerifier.enabled?
  end

  test "missing, non-string, or oversized tokens fail without calling Cloudflare" do
    Net::HTTP.stub(:start, ->(*) { flunk "unexpected HTTP call" }) do
      [ nil, "", [ "token" ], "x" * 2049 ].each do |token|
        assert_equal :failure, TurnstileVerifier.verify(token: token, remote_ip: "203.0.113.1")
      end
    end
  end

  test "posts secret, token, and client IP and accepts a successful verification" do
    http = FakeHttp.new(json_response(success: true), [])
    started = nil
    Net::HTTP.stub(:start, ->(host, port, **options, &block) { started = [ host, port, options ]; block.call(http) }) do
      assert_equal :success, TurnstileVerifier.verify(token: "token-123", remote_ip: "203.0.113.1")
    end

    assert_equal [ "challenges.cloudflare.com", 443 ], started.first(2)
    assert started.last[:use_ssl]
    assert_operator started.last.values_at(:open_timeout, :ssl_timeout, :read_timeout).sum, :<=, 7
    body = URI.decode_www_form(http.requests.first.body).to_h
    assert_equal({ "secret" => "secret-key", "response" => "token-123", "remoteip" => "203.0.113.1" }, body)
  end

  test "rejected tokens are failures" do
    assert_equal :failure, verify_with(json_response(success: false, "error-codes": [ "invalid-input-response" ]))
    assert_equal :failure, verify_with(json_response(success: false, "error-codes": [ "timeout-or-duplicate" ]))
  end

  test "outages, internal errors, and misconfigured secrets fail open" do
    assert_equal :unavailable, verify_with(json_response(success: false, "error-codes": [ "internal-error" ]))
    assert_equal :unavailable, verify_with(json_response(success: false, "error-codes": [ "invalid-input-secret" ]))
    assert_equal :unavailable, verify_with(json_response(success: false, "error-codes": [ "missing-input-secret" ]))
    assert_equal :unavailable, verify_with(Net::HTTPInternalServerError.new("1.1", "500", "Error"))
    assert_equal :unavailable, verify_with(raw_response("not json"))
    assert_equal :unavailable, verify_with(raw_response("true"))
    [ Net::OpenTimeout, Net::ReadTimeout, Timeout::Error, SocketError, Errno::ECONNREFUSED, EOFError, OpenSSL::SSL::SSLError ].each do |error|
      assert_equal :unavailable, verify_with(error), error.name
    end
  end

  test "logs never contain the secret or token" do
    output = StringIO.new
    original_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(output)
    verify_with(json_response(success: false, "error-codes": [ "invalid-input-secret" ]))
    verify_with(Net::ReadTimeout)
  ensure
    Rails.logger = original_logger
    assert_includes output.string, "configuration error"
    assert_includes output.string, "Net::ReadTimeout"
    assert_not_includes output.string, "secret-key"
    assert_not_includes output.string, "token-123"
  end

  private

  def verify_with(response)
    http = FakeHttp.new(response, [])
    Net::HTTP.stub(:start, ->(*, **, &block) { block.call(http) }) do
      TurnstileVerifier.verify(token: "token-123", remote_ip: "203.0.113.1")
    end
  end

  def json_response(payload)
    raw_response(payload.to_json)
  end

  def raw_response(body)
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.instance_variable_set(:@read, true)
    response.instance_variable_set(:@body, body)
    response
  end
end
