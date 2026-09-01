class StripeWebhooksController < ApplicationController
  skip_forgery_protection

  def create
    return head :service_unavailable unless StripeConfiguration.webhook_secret

    event = Stripe::Webhook.construct_event(
      request.raw_post,
      request.headers["Stripe-Signature"],
      StripeConfiguration.webhook_secret
    )
    record, created = persist_event(event)
    ProcessStripeWebhookJob.perform_later(record.id) if created
    head :ok
  rescue JSON::ParserError, Stripe::SignatureVerificationError
    head :bad_request
  end

  private

  def persist_event(event)
    record = StripeWebhookEvent.find_or_initialize_by(stripe_event_id: event.id)
    return [ record, false ] if record.persisted?

    record.update!(event_type: event.type, payload: event.to_hash.deep_stringify_keys)
    [ record, true ]
  rescue ActiveRecord::RecordNotUnique
    [ StripeWebhookEvent.find_by!(stripe_event_id: event.id), false ]
  end
end
