require "test_helper"

class StripePaymentTest < ActiveSupport::TestCase
  test "a verified paid Checkout session fulfils an initial participation once" do
    participation = participation_for
    payment = stripe_payment_for(participation)
    event = webhook_event("checkout.session.completed", checkout_payload(payment, payment_status: "paid"))

    StripeWebhookProcessor.new(event).call

    assert payment.reload.paid?
    assert participation.reload.paid?
    assert_equal "stripe", participation.payment_provider
    assert_equal "pi_test_123", participation.payment_reference
    assert event.reload.processed?
    assert_in_delta payment.paid_at, participation.paid_at, 0.1
  end

  test "an upgrade payment applies only the server-calculated difference" do
    participation = participation_for(category: "no_listing", paid: true)
    upgrade = participation.request_upgrade("leist_member")
    payment = stripe_payment_for(participation, upgrade:)
    event = webhook_event("checkout.session.async_payment_succeeded", checkout_payload(payment, payment_status: "paid"))

    StripeWebhookProcessor.new(event).call

    assert payment.reload.paid?
    assert upgrade.reload.paid?
    assert_equal "stripe", upgrade.payment_provider
    assert_equal "leist_member", participation.reload.category
    assert_equal 20_000, participation.amount_cents
  end

  test "a mismatched Stripe amount never fulfils the local obligation" do
    participation = participation_for
    payment = stripe_payment_for(participation)
    payload = checkout_payload(payment, payment_status: "paid").merge("amount_total" => payment.amount_cents - 1)
    event = webhook_event("checkout.session.completed", payload)

    assert_raises(ActiveRecord::RecordInvalid) { StripeWebhookProcessor.new(event).call }

    assert participation.reload.pending?
    assert payment.reload.checkout_created?
    assert event.reload.failed?
  end

  private

  def stripe_payment_for(participation, upgrade: nil)
    StripePayment.create!(
      participation:, participation_upgrade: upgrade,
      payment_kind: upgrade ? :upgrade : :initial,
      obligation_key: upgrade ? "participation-upgrade:#{upgrade.id}" : "participation:#{participation.id}",
      attempt: 1, amount_cents: upgrade ? upgrade.difference_cents : participation.amount_cents,
      idempotency_key: "test-#{SecureRandom.hex(8)}", status: :checkout_created,
      checkout_session_id: "cs_test_#{SecureRandom.hex(8)}"
    )
  end

  def checkout_payload(payment, payment_status:)
    {
      "id" => payment.checkout_session_id,
      "client_reference_id" => payment.id.to_s,
      "payment_status" => payment_status,
      "payment_intent" => "pi_test_123",
      "amount_total" => payment.amount_cents,
      "currency" => "chf"
    }
  end

  def webhook_event(type, object)
    StripeWebhookEvent.create!(
      stripe_event_id: "evt_#{SecureRandom.hex(8)}", event_type: type,
      payload: { "data" => { "object" => object } }
    )
  end
end
