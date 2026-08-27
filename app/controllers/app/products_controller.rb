class App::ProductsController < App::BaseController
  def index
    redirect_to app_print_order_path
  end
end
