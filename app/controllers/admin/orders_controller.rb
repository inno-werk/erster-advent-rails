class Admin::OrdersController < Admin::BaseController
  def index
    @statuses = Order.distinct.order(:accept_order).pluck(:accept_order)
    @status = list_choice(:status, @statuses)
    scope = search_list(Order.left_joins(:product, :customer), "products.title", "users.email", "orders.order_no")
    scope = scope.where(accept_order: @status) if @status
    @orders = paginate_list(scope.includes(:product, :customer).order(created_at: :desc, id: :desc))
  end
end
