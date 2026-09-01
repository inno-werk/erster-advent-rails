class StripeCheckoutSessionCreator
  INTEGRATION_IDENTIFIER = "annual-fee-xkqjrtmz".freeze

  Result = Data.define(:payment, :url)

  def initialize(participation:, success_url:, cancel_url:, client: StripeConfiguration.client)
    @participation = participation
    @success_url = success_url
    @cancel_url = cancel_url
    @client = client
  end

  def call
    payment = build_payment
    session = @client.v1.checkout.sessions.create(session_params(payment), { idempotency_key: payment.idempotency_key })
    payment.update!(
      status: :checkout_created,
      checkout_session_id: session.id,
      checkout_url: session.url,
      expires_at: Time.zone.at(session.expires_at)
    )
    Result.new(payment:, url: session.url)
  rescue Stripe::StripeError => error
    payment&.update!(status: :failed, failure_code: error.code.to_s.presence || error.class.name)
    raise
  end

  private

  def build_payment
    @participation.with_lock do
      @participation.reload
      upgrade = @participation.pending_upgrade
      kind = upgrade ? :upgrade : :initial
      amount = upgrade ? upgrade.difference_cents : @participation.amount_cents
      obligation_key = upgrade ? "participation-upgrade:#{upgrade.id}" : "participation:#{@participation.id}"

      existing = StripePayment.active.find_by(obligation_key:)
      if existing&.checkout_created? && existing.expires_at&.future? && existing.checkout_url.present?
        return existing
      elsif existing
        existing.update!(status: :expired)
      end

      attempt = StripePayment.where(obligation_key:).maximum(:attempt).to_i + 1
      StripePayment.create!(
        participation: @participation, participation_upgrade: upgrade, payment_kind: kind,
        obligation_key:, attempt:, amount_cents: amount, currency: "chf",
        idempotency_key: "#{obligation_key}-attempt-#{attempt}"
      )
    end
  end

  def session_params(payment)
    {
      mode: "payment",
      locale: "de",
      customer_email: @participation.user.email,
      client_reference_id: payment.id.to_s,
      integration_identifier: INTEGRATION_IDENTIFIER,
      metadata: {
        stripe_payment_id: payment.id.to_s,
        participation_id: @participation.id.to_s,
        participation_upgrade_id: payment.participation_upgrade_id.to_s
      },
      line_items: [ {
        price_data: {
          currency: "chf",
          unit_amount: payment.amount_cents,
          product_data: { name: description(payment) }
        },
        quantity: 1
      } ],
      success_url: @success_url,
      cancel_url: @cancel_url
    }
  end

  def description(payment)
    if payment.upgrade?
      "Erhöhung #{payment.participation_upgrade.category_title} – Erster Advent #{@participation.year}"
    else
      "Teilnahme #{@participation.category_title} – Erster Advent #{@participation.year}"
    end
  end
end
