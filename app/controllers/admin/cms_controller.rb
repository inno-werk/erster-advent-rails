class Admin::CmsController < Admin::BaseController
  PAGE = "home".freeze

  def edit
    load_blocks
    @site_setting = SiteSetting.current
  end

  def update
    @site_setting = SiteSetting.current

    if @site_setting.update(site_setting_params)
      redirect_to edit_admin_cms_path, notice: "Die Farbe des Jahres wurde gespeichert."
    else
      load_blocks
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def load_blocks
    blocks = CmsBlock.for_page(PAGE).ordered
                     .with_rich_text_title.with_rich_text_content.with_attached_image
    @sections = blocks.select(&:section?)
    @faq_items = blocks.select(&:faq_item?)
  end

  def site_setting_params
    params.require(:site_setting).permit(:brand_color)
  end
end
