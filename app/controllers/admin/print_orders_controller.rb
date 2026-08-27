class Admin::PrintOrdersController < Admin::BaseController
  before_action :load_order, only: [ :show, :edit, :update ]

  def index
    @year = list_year
    @product_id = list_choice(:product_id, PrintProduct.pluck(:id))
    @contents = list_choice(:contents, %w[ordered empty])
    @filter_products = PrintProduct.ordered
    scope = PrintOrder.for_year(@year)
    @ordered_count = scope.where(id: PrintOrderItem.select(:print_order_id)).count
    @totals = PrintOrderItem.joins(:print_order, :print_product).merge(scope)
      .group("print_products.id", "print_products.title").sum(:quantity)
    scope = search_list(scope.left_joins(user: :business), "users.email", "users.name", "businesses.business_name")
    scope = scope.where(id: PrintOrderItem.where(print_product_id: @product_id).select(:print_order_id)) if @product_id
    scope = scope.where(id: PrintOrderItem.select(:print_order_id)) if @contents == "ordered"
    scope = scope.where.not(id: PrintOrderItem.select(:print_order_id)) if @contents == "empty"
    @print_orders = paginate_list(scope.includes(:items, user: :business).order(updated_at: :desc, id: :desc))
  end

  def show
  end

  def edit
    @products = PrintProduct.ordered.with_attached_image
  end

  def update
    @products = PrintProduct.ordered.with_attached_image
    saved = @print_order.with_lock do
      quantities = params.fetch(:quantities, ActionController::Parameters.new).permit(*@products.map { |product| product.id.to_s }).to_h
      @print_order.update_quantities(quantities, products: @products)
    end
    if saved
      redirect_to admin_print_order_path(@print_order), notice: "Printbestellung korrigiert."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def load_order
    @print_order = PrintOrder.includes(items: :print_product).find(params[:id])
  end
end
