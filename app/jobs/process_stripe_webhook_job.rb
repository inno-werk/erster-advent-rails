class ProcessStripeWebhookJob < ApplicationJob
  queue_as :default

  retry_on ActiveRecord::Deadlocked, wait: :polynomially_longer, attempts: 5
  retry_on Stripe::APIConnectionError, wait: :polynomially_longer, attempts: 8

  def perform(stripe_webhook_event_id)
    event = StripeWebhookEvent.find(stripe_webhook_event_id)
    return if event.processed?

    StripeWebhookProcessor.new(event).call
  end
end
