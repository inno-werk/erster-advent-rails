require "test_helper"

class StripeCheckoutSessionCreatorTest < ActiveSupport::TestCase
  test "creates a hosted one-time CHF Checkout session from the local fee snapshot" do
    participation = participation_for
    client = FakeStripeClient.new

    result = StripeCheckoutSessionCreator.new(
      participation:, success_url: "https://example.com/success?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: "https://example.com/cancel", client:
    ).call

    payment = result.payment.reload
    assert payment.checkout_created?
    assert_equal "cs_test_created", payment.checkout_session_id
    assert_equal "https://checkout.stripe.test/session", result.url
    assert_equal "payment", client.params[:mode]
    assert_equal "chf", client.params.dig(:line_items, 0, :price_data, :currency)
    assert_equal 20_000, client.params.dig(:line_items, 0, :price_data, :unit_amount)
    assert_equal participation.user.email, client.params[:customer_email]
    assert_equal payment.id.to_s, client.params[:client_reference_id]
    assert_equal payment.idempotency_key, client.options[:idempotency_key]
    assert_not client.params.key?(:payment_method_types)
  end

  test "creates a new attempt after an earlier Checkout failed" do
    participation = participation_for
    failed_payment = StripePayment.create!(
      participation:, payment_kind: :initial,
      obligation_key: "participation:#{participation.id}", attempt: 1,
      amount_cents: participation.amount_cents, idempotency_key: "failed-attempt",
      status: :failed
    )

    result = StripeCheckoutSessionCreator.new(
      participation:, success_url: "https://example.com/success",
      cancel_url: "https://example.com/cancel", client: FakeStripeClient.new
    ).call

    assert_equal 2, result.payment.attempt
    assert_equal failed_payment.obligation_key, result.payment.obligation_key
    assert result.payment.checkout_created?
  end

  class FakeStripeClient
    attr_reader :params, :options

    def v1 = self
    def checkout = self
    def sessions = self

    def create(params, options)
      @params = params
      @options = options
      Struct.new(:id, :url, :expires_at).new("cs_test_created", "https://checkout.stripe.test/session", 1.hour.from_now.to_i)
    end
  end
end
