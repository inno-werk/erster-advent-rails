class App::ParticipationsController < App::BaseController
  def show
    @participation = current_participation
  end

  def edit
    @participation = current_participation || current_user.participations.build(year: EventConfiguration.year)
    if @participation.pending_upgrade
      redirect_to payment_app_participation_path
    elsif @participation.paid? && !@participation.upgrade_available?
      redirect_to app_participation_path
    end
  end

  def update
    current_user.with_lock do
      @participation = current_user.participations.for_year.lock.first_or_initialize(year: EventConfiguration.year)
      if @participation.paid?
        @upgrade = @participation.request_upgrade(params.require(:participation).permit(:category)[:category])
        if @upgrade.persisted?
          redirect_to payment_app_participation_path
        else
          render :edit, status: :unprocessable_entity
        end
      elsif @participation.update(category: params.require(:participation).permit(:category)[:category])
        redirect_to app_participation_path
      else
        render :edit, status: :unprocessable_entity
      end
    end
  end

  def payment
    @participation = current_participation
    @stripe_payment = returned_stripe_payment
    if @participation.nil?
      redirect_to edit_app_participation_path
    elsif payment_confirmed?
      render :payment_confirmation
    elsif !@participation.payment_due?
      redirect_to app_participation_path
    end
  end

  private

  def payment_confirmed?
    params[:status] == "success" && @participation&.paid? && !@participation.payment_due?
  end

  def returned_stripe_payment
    return unless @participation && params[:session_id].present?

    @participation.stripe_payments.find_by(checkout_session_id: params[:session_id])
  end
end
