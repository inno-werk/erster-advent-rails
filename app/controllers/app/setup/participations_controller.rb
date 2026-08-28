class App::Setup::ParticipationsController < App::Setup::BaseController
  def show
    @participation = current_participation || current_user.participations.build(year: EventConfiguration.year)
    redirect_to app_setup_payment_path if @participation.paid?
  end

  def update
    current_user.with_lock do
      @participation = current_user.participations.for_year.lock.first_or_initialize(year: EventConfiguration.year)
      if @participation.paid?
        redirect_to app_setup_payment_path, status: :see_other
      elsif @participation.update(category: params.require(:participation).permit(:category)[:category])
        redirect_to app_setup_payment_path, status: :see_other
      else
        render :show, status: :unprocessable_entity
      end
    end
  end

  private

  def setup_step
    1
  end
end
