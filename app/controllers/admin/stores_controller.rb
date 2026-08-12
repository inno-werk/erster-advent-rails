class Admin::StoresController < Admin::BaseController
  before_action :load_business, only: [ :show, :update ]

  def index
    @q = params[:q].to_s.strip
    @status = params[:status].presence
    @sort = params[:sort].presence || "name_asc"

    scope = Business.includes(:user)
    scope = scope.where("business_name ILIKE ?", "%#{@q}%") if @q.present?
    scope = scope.where(status: @status) if @status.present? && Business.statuses.key?(@status)
    scope = @sort == "name_desc" ? scope.order(business_name: :desc) : scope.order(business_name: :asc)

    @pagy, @businesses = pagy(scope, items: params[:per]&.to_i || 10)
  end

  def show
    @owner = @business.user
  end

  def update
    if @business.update(business_params)
      redirect_to admin_store_path(@business), notice: "Geschäft wurde aktualisiert."
    else
      redirect_to admin_store_path(@business), alert: @business.errors.full_messages.to_sentence, status: :unprocessable_entity
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
      :status
    )

    permitted[:tags] = Array(permitted[:tags]).compact_blank
    permitted[:categories] = Array(permitted[:categories]).compact_blank
    permitted
  end
end
