module TestPaymentProcessing
  extend ActiveSupport::Concern

  included do
    before_action :require_test_payments
  end

  def prepare_test_payment(continue_setup:)
    @participation = current_participation
    return redirect_to(continue_setup ? app_setup_participation_path : edit_app_participation_path) unless @participation
    return redirect_to(continue_setup ? app_setup_payment_path : app_participation_path) unless @participation.payment_due?
    return redirect_to payment_app_participation_path if continue_setup && @participation.paid?

    @upgrade = @participation.pending_upgrade
    @amount_cents = @participation.amount_due_cents
    @token = verifier.generate({
      "participation_id" => @participation.id,
      "upgrade_id" => @upgrade&.id,
      "amount_cents" => @amount_cents,
      "category" => @participation.category,
      "selected_at" => @participation.selected_at.iso8601(6),
      "continue_setup" => continue_setup
    }, expires_in: 30.minutes)
  end

  def create
    quote = verifier.verified(params[:token].to_s)
    return render plain: "Die Testzahlung ist ungültig oder abgelaufen. Bitte öffnen Sie die Zahlungsseite erneut.", status: :unprocessable_entity unless quote

    participation = current_user.participations.for_year.find(quote.fetch("participation_id"))
    participation.with_lock do
      if quote["upgrade_id"]
        upgrade = participation.upgrades.find(quote["upgrade_id"])
        unless upgrade.paid?
          return stale_quote unless upgrade.payable? && upgrade.difference_cents == quote["amount_cents"]

          upgrade.mark_paid!
          upgrade.update!(payment_provider: "dummy", payment_reference: "dummy-upgrade-#{upgrade.id}")
        end
      elsif participation.pending?
        return stale_quote unless participation.amount_cents == quote["amount_cents"] &&
          participation.category == quote["category"] && participation.selected_at.iso8601(6) == quote["selected_at"]

        participation.mark_paid!
        participation.update!(payment_provider: "dummy", payment_reference: "dummy-membership-#{participation.id}")
      end
    end
    redirect_to quote["continue_setup"] ? app_setup_payment_path(status: "success") : payment_app_participation_path(status: "success"), status: :see_other
  end

  private :prepare_test_payment

  private

  def require_test_payments
    head :not_found unless EventConfiguration.dummy_payments_enabled?
  end

  def verifier
    Rails.application.message_verifier("dummy-membership-payment")
  end

  def stale_quote
    render plain: "Ihre Mitgliedschaft hat sich geändert. Bitte öffnen Sie die Zahlungsseite erneut.", status: :conflict
  end
end
