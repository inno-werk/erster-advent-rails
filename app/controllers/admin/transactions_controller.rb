class Admin::TransactionsController < Admin::BaseController
  def index
    @status = list_choice(:status, %w[pending approved rejected])
    scope = search_list(Payment.left_joins(:user), "users.email", "payments.customer_email", "payments.plan")
    scope = scope.where(is_verified: @status == "pending" ? [ "Pending", "pending", "" ] : @status) if @status
    @payments = paginate_list(scope.includes(:user).order(created_at: :desc, id: :desc))
  end
end
