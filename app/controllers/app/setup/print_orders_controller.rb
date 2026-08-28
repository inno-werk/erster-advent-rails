class App::Setup::PrintOrdersController < App::Setup::BaseController
  before_action :load_catalogue

  def show
    @print_order = current_user.print_orders.for_year.includes(items: :print_product).first ||
      current_user.print_orders.build(year: EventConfiguration.year)
  end

  def update
    return redirect_to app_setup_print_order_path, status: :see_other unless @distribution.orders_open?

    current_user.with_lock do
      @print_order = current_user.print_orders.for_year.lock.first_or_initialize(year: EventConfiguration.year)
      quantities = quantity_params
      if @print_order.new_record? && quantities.values.all? { |quantity| quantity.to_s.match?(/\A0*\z/) }
        redirect_to after_print_order_path, status: :see_other
      elsif @print_order.update_quantities(quantities, products: @products, maximum_quantity: 10)
        redirect_to after_print_order_path, status: :see_other
      else
        render :show, status: :unprocessable_entity
      end
    end
  end

  private

  def setup_step
    3
  end

  def load_catalogue
    @distribution = PrintDistribution.current
    @products = PrintProduct.available.ordered.with_attached_image
  end

  def quantity_params
    params.fetch(:quantities, ActionController::Parameters.new).permit(*@products.map { |product| product.id.to_s }).to_h
  end
end
