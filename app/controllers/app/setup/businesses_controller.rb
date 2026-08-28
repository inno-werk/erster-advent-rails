class App::Setup::BusinessesController < App::Setup::BaseController
  def show
    redirect_to app_mystore_path unless current_user.business_editing_allowed?
  end

  private

  def setup_step
    4
  end
end
