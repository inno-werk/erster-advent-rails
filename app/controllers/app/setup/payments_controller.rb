class App::Setup::PaymentsController < App::Setup::BaseController
  def show
    @participation = current_participation
    if @participation.nil?
      redirect_to app_setup_participation_path
    elsif @participation.pending_upgrade
      redirect_to payment_app_participation_path
    elsif @participation.paid?
      if params[:status] == "success"
        render :confirmation
      else
        redirect_to app_setup_payment_path(status: "success")
      end
    end
  end

  private

  def setup_step
    2
  end
end
