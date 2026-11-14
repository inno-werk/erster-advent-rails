require "test_helper"

class AuthSpamProtectionTest < ActiveSupport::TestCase
  test "form token round-trips the render time" do
    rendered = Time.zone.at(1_800_000_000.25)
    travel_to rendered + 5.seconds do
      assert_in_delta rendered.to_f, AuthSpamProtection.rendered_at(AuthSpamProtection.form_token(rendered)).to_f, 0.001
    end
  end

  test "tampered, foreign-purpose, malformed, and non-string tokens are rejected" do
    token = AuthSpamProtection.form_token
    foreign = AuthSpamProtection.verifier.generate(Time.current.to_f, purpose: :other)
    non_numeric = AuthSpamProtection.verifier.generate("now", purpose: AuthSpamProtection::TOKEN_PURPOSE)

    [ "#{token}x", foreign, non_numeric, "garbage", "", nil, [ token ], { "a" => token } ].each do |value|
      assert_nil AuthSpamProtection.rendered_at(value), "accepted #{value.inspect}"
    end
  end

  test "tokens older than the maximum form age are rejected" do
    token = AuthSpamProtection.form_token
    travel 23.hours + 59.minutes do
      assert AuthSpamProtection.rendered_at(token)
    end
    travel 24.hours + 1.minute do
      assert_nil AuthSpamProtection.rendered_at(token)
    end
    assert_nil AuthSpamProtection.rendered_at(AuthSpamProtection.form_token(25.hours.ago))
  end

  test "rate limit store counts with the backend and fails open on cache database errors" do
    store = AuthSpamProtection::RateLimitStore.new
    store.backend = ActiveSupport::Cache::MemoryStore.new
    assert_equal 1, store.increment("key", 1, expires_in: 1.minute)
    assert_equal 2, store.increment("key", 1, expires_in: 1.minute)

    [ ActiveRecord::StatementInvalid.new("missing table"), ArgumentError.new("No unique index found for key_hash") ].each do |error|
      failing = Object.new
      failing.define_singleton_method(:increment) { |*, **| raise error }
      store.backend = failing
      assert_nil store.increment("key", 1, expires_in: 1.minute)
    end

    failing = Object.new
    failing.define_singleton_method(:increment) { |*, **| raise ArgumentError, "other" }
    store.backend = failing
    assert_raises(ArgumentError) { store.increment("key", 1, expires_in: 1.minute) }
  end
end
