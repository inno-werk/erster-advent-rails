class Admin::TransactionRequestsController < Admin::BaseController
  def index
    @sort = list_choice(:sort, %w[newest oldest], default: "newest")
    scope = search_list(Payment.left_joins(:user).where(is_verified: [ "Pending", "pending", "" ]), "users.email", "payments.customer_email", "payments.plan")
    direction = @sort == "oldest" ? :asc : :desc
    @payments = paginate_list(scope.includes(:user).order(created_at: direction, id: direction))
  end
end
