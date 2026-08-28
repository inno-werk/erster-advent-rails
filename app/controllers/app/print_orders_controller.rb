class App::PrintOrdersController < App::BaseController
  before_action :load_order
  before_action :ensure_orders_open, only: [ :edit, :update ]

  def show
  end

  def edit
    @products = PrintProduct.available.ordered.with_attached_image
  end

  def update
    @products = PrintProduct.available.ordered.with_attached_image
    current_user.with_lock do
      @print_order = current_user.print_orders.for_year.lock.first_or_initialize(year: EventConfiguration.year)
      if @print_order.update_quantities(quantity_params, products: @products, maximum_quantity: 10)
        redirect_to app_print_order_path
      else
        render :edit, status: :unprocessable_entity
      end
    end
  end

  private

  def ensure_orders_open
    redirect_to app_print_order_path unless PrintDistribution.current.orders_open?
  end

  def load_order
    @print_order = current_user.print_orders.for_year.includes(items: { print_product: { image_attachment: :blob } }).first ||
      current_user.print_orders.build(year: EventConfiguration.year)
  end

  def quantity_params
    params.fetch(:quantities, ActionController::Parameters.new).permit(*@products.map { |product| product.id.to_s }).to_h
  end
end
