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
        redirect_to setup_flow? ? payment_app_participation_path(setup: 1) : app_participation_path
      else
        render :edit, status: :unprocessable_entity
      end
    end
  end

  def payment
    @participation = current_participation
    @continue_setup = params[:setup] == "1" && !@participation&.paid?
    if @participation.nil?
      redirect_to edit_app_participation_path
    elsif !@participation.payment_due?
      redirect_to app_participation_path
    end
  end

  private

  def setup_flow?
    %w[edit update].include?(action_name) && params[:setup] != "0" && !@participation&.paid?
  end

  def store_layout
    action_name == "payment" ? "payment" : super
  end
end
