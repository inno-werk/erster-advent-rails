class Admin::PrintDistributionsController < Admin::BaseController
  def update
    @distribution = PrintDistribution.current
    if @distribution.update(params.require(:print_distribution).permit(:distribution_on, :order_deadline_on))
      redirect_to admin_print_products_path, status: :see_other
    else
      @products = paginate_list(PrintProduct.ordered.with_attached_image)
      render "admin/print_products/index", status: :unprocessable_entity
    end
  end
end
