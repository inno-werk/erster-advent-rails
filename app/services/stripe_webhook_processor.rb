class StripeWebhookProcessor
  def initialize(webhook_event)
    @webhook_event = webhook_event
  end

  def call
    case @webhook_event.event_type
    when "checkout.session.completed"
      process_checkout_completed
    when "checkout.session.async_payment_succeeded"
      process_checkout_paid
    when "checkout.session.async_payment_failed"
      update_checkout(:failed)
    when "checkout.session.expired"
      update_checkout(:expired)
    when "payment_intent.payment_failed"
      update_payment_intent_failure
    end
    @webhook_event.update!(status: :processed, processed_at: Time.current, processing_error: nil)
  rescue StandardError => error
    @webhook_event.update!(status: :failed, processing_error: "#{error.class}: #{error.message}".truncate(2_000))
    raise
  end

  private

  def process_checkout_completed
    session = event_object
    if session["payment_status"] == "paid"
      fulfill_checkout(session)
    else
      update_checkout(:processing)
    end
  end

  def process_checkout_paid
    fulfill_checkout(event_object)
  end

  def fulfill_checkout(session)
    payment = checkout_payment(session)
    validate_amount!(payment, session)
    payment.update!(payment_intent_id: stripe_id(session["payment_intent"])) if session["payment_intent"].present?
    payment.fulfill!(payment_intent_id: stripe_id(session["payment_intent"]))
  end

  def update_checkout(status)
    payment = checkout_payment(event_object)
    return if payment.paid?

    payment.update!(status:)
  end

  def update_payment_intent_failure
    payment = StripePayment.find_by(payment_intent_id: event_object.fetch("id"))
    return unless payment && !payment.paid?

    payment.update!(status: :failed, failure_code: event_object.dig("last_payment_error", "code"))
  end

  def checkout_payment(session)
    payment = StripePayment.find_by!(checkout_session_id: session.fetch("id"))
    referenced_id = session["client_reference_id"].to_s
    raise ActiveRecord::RecordNotFound, "Checkout reference mismatch" unless referenced_id == payment.id.to_s

    payment
  end

  def validate_amount!(payment, session)
    return if session["amount_total"].to_i == payment.amount_cents && session["currency"] == payment.currency

    payment.errors.add(:base, "Stripe-Betrag oder Währung stimmt nicht mit dem Zahlungsauftrag überein.")
    raise ActiveRecord::RecordInvalid, payment
  end

  def event_object
    @webhook_event.payload.fetch("data").fetch("object")
  end

  def stripe_id(value)
    value.is_a?(Hash) ? value["id"] : value
  end
end
