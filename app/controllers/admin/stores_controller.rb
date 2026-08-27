class Admin::StoresController < Admin::BaseController
  before_action :load_business, only: [ :show, :preview, :edit, :update, :confirm ]

  def index
    @status = list_choice(:status, Business.statuses.keys)
    @sort = list_choice(:sort, %w[name_asc name_desc], default: "name_asc")

    scope = search_list(Business.left_joins(:user).includes(:user), "businesses.business_name", "users.email", "businesses.address")
    scope = scope.where(status: @status) if @status
    scope = @sort == "name_desc" ? scope.order(business_name: :desc) : scope.order(business_name: :asc)

    @businesses = paginate_list(scope.order(id: :asc))
  end

  def show
    @owner = @business.user
    @participations = @owner.participations.includes(:upgrades).order(year: :desc).to_a
    @current_participation = @participations.find { |participation| participation.year == EventConfiguration.year }
    @print_orders = @owner.print_orders.includes(items: :print_product).order(year: :desc, updated_at: :desc)
    @gallery_images = {
      "Hauptbild" => @business.main_image, "Galeriebild 1" => @business.image_gallery1,
      "Galeriebild 2" => @business.image_gallery2, "Galeriebild 3" => @business.image_gallery3
    }.select { |_label, image| image.attached? }
  end

  def edit
  end

  def preview
    @images = [ @business.main_image, @business.image_gallery1, @business.image_gallery2, @business.image_gallery3 ].select(&:attached?)
    response.headers["X-Robots-Tag"] = "noindex, nofollow"
    response.headers["Cache-Control"] = "no-store"
    render layout: "marketing"
  end

  def confirm
    @business.update!(status: :confirmed)
    redirect_to admin_store_path(@business), notice: "Geschäft bestätigt. Die öffentliche Sichtbarkeit hängt zusätzlich von der Teilnahme ab."
  end

  def update
    if @business.update(business_params)
      redirect_to admin_store_path(@business), notice: "Geschäft wurde aktualisiert."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def load_business
    @business = Business.includes(:user).find_by(id: params[:id])
    return if @business

    redirect_to admin_stores_path, alert: "Store wurde nicht gefunden." and return
  end

    def business_params
    return {} unless params[:business]

    permitted = params.require(:business).permit(
      :status, :business_name, :phone, :address, :billing_address, :contact_name,
      :email, :website, :instagram, :tiktok, :linkedin, :facebook, :map_link,
      :description, :first_advent_specialities, :main_image, :image_gallery1,
      :image_gallery2, :image_gallery3, categories: []
    )

    permitted[:categories] = Array(permitted[:categories]).compact_blank if permitted.key?(:categories)
    permitted
  end
end
