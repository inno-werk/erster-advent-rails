class App::MystoreController < App::BaseController
  before_action :require_business_editing, except: :show
  before_action :set_business, except: :create
  before_action :initialize_business, only: :edit
  before_action :set_categories, only: :edit


  def show
    return unless current_user.business_editing_allowed?
    return redirect_to edit_app_mystore_path unless @business

    prepare_view_data(@business)
  end

  def edit
    prepare_form_data
  end

  def create
    save_business
  end

  def update
    save_business
  end

  def edit_main_image
    @mystore = current_user.mystore
    # render a form to upload new image here
  end

  # No the best method, but works for now
  def purge_image
    puts "Purge image called"
    puts params
    image = params[:image]
    case params[:image]
    when "main_image"
      @business.main_image.purge
    when "image_gallery1"
      @business.image_gallery1.purge
    when "image_gallery2"
      @business.image_gallery2.purge
    when "image_gallery3"
      @business.image_gallery3.purge
    end
    render turbo_stream: turbo_stream.replace("preview-#{params[:image]}") {
      view_context.image_tag(
      view_context.asset_path("placeholder.png"),
      id: "preview-#{params[:image]}",
      class: "h-full w-full object-cover"
      )
    }
 end

  private

  def require_business_editing
    redirect_to app_mystore_path, status: :see_other unless current_user.business_editing_allowed?
  end


  def set_categories
  @categories = BUSINESS_CATEGORIES
  @selected_categories = @business.categories || []
  end

  def set_business
    @business = current_user.business
  end

  def initialize_business
    @business = current_user.business_for_editing
  end

  def save_business
    current_user.with_lock do
      @business = current_user.reload_business || current_user.build_registration_business
      if @business.update(business_params)
        redirect_to app_mystore_path, notice: "Geschäft wurde aktualisiert."
      else
        set_categories
        prepare_form_data
        render :edit, status: :unprocessable_entity
      end
    end
  end

  def business_params
    return {} unless params[:business]

    permitted = params.require(:business).permit(
      :business_name,
      :phone,
      :address,
      :email,
      :website,
      :instagram,
      :tiktok,
      :linkedin,
      :facebook,
      :map_link,
      :description,
      :first_advent_specialities,
      :main_image,
      :image_gallery1,
      :image_gallery2,
      :image_gallery3,
      :contact_name,
      :billing_address,
      categories: []
    )

    permitted[:categories] = Array(permitted[:categories]).compact_blank
    permitted
  end

  def prepare_view_data(business)
    @gallery_images = [
      business.main_image,
      business.image_gallery1,
      business.image_gallery2,
      business.image_gallery3
    ].compact_blank
  end

  def prepare_form_data
    prepare_view_data(@business) if @business&.persisted?

    @selected_categories = Array(@business&.categories).compact_blank
  end
end
