class App::StripeCheckoutsController < App::BaseController
  def create
    participation = current_participation
    return redirect_to(edit_app_participation_path) unless participation
    return redirect_to(app_participation_path) unless participation.payment_due?
    return redirect_to(payment_path) unless StripeConfiguration.ready?

    result = StripeCheckoutSessionCreator.new(
      participation:,
      success_url: success_url,
      cancel_url: payment_url
    ).call
    redirect_to result.url, allow_other_host: true, status: :see_other
  rescue Stripe::StripeError
    redirect_to payment_path, alert: "Stripe konnte nicht erreicht werden. Bitte versuchen Sie es erneut."
  end

  private

  def continue_setup?
    ActiveModel::Type::Boolean.new.cast(params[:continue_setup])
  end

  def payment_path
    continue_setup? ? app_setup_payment_path : payment_app_participation_path
  end

  def payment_url
    continue_setup? ? app_setup_payment_url : payment_app_participation_url
  end

  def success_url
    "#{payment_url}?status=success&session_id={CHECKOUT_SESSION_ID}"
  end
end
