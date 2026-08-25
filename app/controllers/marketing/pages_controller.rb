class Marketing::PagesController < Marketing::BaseController
  def home
    @featured_products = Product.includes(:user).order(created_at: :desc).limit(4)
    @featured_businesses = Business.confirmed.includes(:user).order(created_at: :desc).limit(3)

    home_blocks = CmsBlock.for_page("home").active.ordered
                          .with_rich_text_title.with_rich_text_content
                          .with_attached_image
    @cms_blocks = home_blocks.select(&:section?)
    @cms_faq_items = home_blocks.select(&:faq_item?)
  end

  def about
    @totals = {
      products: Product.count,
      businesses: Business.confirmed.count,
      orders: Order.count
    }
  end
end
