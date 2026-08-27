class Admin::PrintProductsController < Admin::BaseController
  before_action :load_product, only: [ :edit, :update ]

  def index
    @active = list_choice(:active, %w[true false])
    scope = search_list(PrintProduct.ordered.with_attached_image, "print_products.title", "print_products.description")
    scope = scope.where(active: @active == "true") if @active
    @products = paginate_list(scope)
    @distribution = PrintDistribution.current
  end

  def new
    @product = PrintProduct.new
  end

  def create
    @product = PrintProduct.new(product_params)
    if @product.save
      redirect_to admin_print_products_path, notice: "Printprodukt erstellt."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @product.update(product_params)
      redirect_to admin_print_products_path, notice: "Printprodukt gespeichert."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def load_product
    @product = PrintProduct.find(params[:id])
  end

  def product_params
    params.require(:print_product).permit(:title, :description, :image, :active, :position)
  end
end
