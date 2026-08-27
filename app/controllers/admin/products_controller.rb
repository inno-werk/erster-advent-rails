class Admin::ProductsController < Admin::BaseController
  def index
    @sort = list_choice(:sort, %w[newest price_asc price_desc], default: "newest")
    scope = search_list(Product.left_joins(user: :business), "products.title", "businesses.business_name")
    scope = case @sort
    when "price_asc" then scope.order(price: :asc)
    when "price_desc" then scope.order(price: :desc)
    else scope.order(created_at: :desc)
    end
    @products = paginate_list(scope.includes(user: :business).order(id: :desc))
  end
end
