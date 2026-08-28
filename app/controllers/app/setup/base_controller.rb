class App::Setup::BaseController < App::BaseController
  layout "setup"
  helper_method :setup_step, :after_print_order_path

  private

  def after_print_order_path
    current_user.business_editing_allowed? ? app_setup_business_path : app_mystore_path
  end
end
