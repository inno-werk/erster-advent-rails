class Marketing::StoresController < Marketing::BaseController
  STORES_PER_PAGE = 9

  before_action :load_store, only: :show

  def index
    @search_term = params[:q].to_s.strip
    @page = [ params[:page].to_i, 1 ].max

    scope = if @search_term.present?
      Business.publicly_visible.search(@search_term)
    else
      Business.publicly_visible
    end

    @businesses = scope
      .includes(:rich_text_description, main_image_attachment: :blob)
      .order(:business_name)
      .limit(STORES_PER_PAGE)
      .offset((@page - 1) * STORES_PER_PAGE)

    @has_more_stores = scope.offset(@page * STORES_PER_PAGE).exists?
    @next_page = @page + 1

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def show
    @owner = @business.user
    @products = @owner ? @owner.products.order(created_at: :desc) : Product.none
    @images = [
      @business.main_image,
      @business.image_gallery1,
      @business.image_gallery2,
      @business.image_gallery3
    ].select(&:attached?)
  end

  private

  def load_store
    @business = Business.publicly_visible.includes(:user).find_by(id: params[:id])

    return if @business

    redirect_to marketing_stores_path, alert: "Store wurde nicht gefunden." and return
  end
end
