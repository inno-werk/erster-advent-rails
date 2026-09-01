require "test_helper"
require "minitest/mock"

class StripeWebhooksControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "accepts a signed event once and enqueues durable processing" do
    secret = "whsec_test"
    payload = { id: "evt_unique", type: "checkout.session.completed", data: { object: { id: "cs_test" } } }.to_json
    timestamp = Time.current
    signature = Stripe::Webhook::Signature.compute_signature(timestamp, payload, secret)
    header = Stripe::Webhook::Signature.generate_header(timestamp, signature)

    StripeConfiguration.stub(:webhook_secret, secret) do
      assert_enqueued_with(job: ProcessStripeWebhookJob) do
        post stripe_webhooks_path, params: payload, headers: { "CONTENT_TYPE" => "application/json", "Stripe-Signature" => header }
      end
      assert_response :ok
      assert_no_enqueued_jobs do
        post stripe_webhooks_path, params: payload, headers: { "CONTENT_TYPE" => "application/json", "Stripe-Signature" => header }
      end
      assert_response :ok
    end

    assert_equal 1, StripeWebhookEvent.where(stripe_event_id: "evt_unique").count
  end

  test "rejects an invalid webhook signature" do
    StripeConfiguration.stub(:webhook_secret, "whsec_test") do
      post stripe_webhooks_path, params: "{}", headers: { "CONTENT_TYPE" => "application/json", "Stripe-Signature" => "bad" }
    end

    assert_response :bad_request
    assert_equal 0, StripeWebhookEvent.count
  end
end
