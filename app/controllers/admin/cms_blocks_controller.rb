class Admin::CmsBlocksController < Admin::BaseController
  before_action :load_block, only: [ :edit, :update, :destroy, :move ]

  def new
    @block = CmsBlock.new(page: Admin::CmsController::PAGE, block_type: requested_type)
  end

  def create
    @block = CmsBlock.new(block_params)
    @block.page = Admin::CmsController::PAGE
    @block.block_type = requested_type_from(params[:cms_block][:block_type])

    if @block.save
      redirect_to edit_admin_cms_path, notice: "#{label_for(@block)} wurde hinzugefügt."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    # The block type is fixed once created; only its content is editable.
    if @block.update(block_params)
      redirect_to edit_admin_cms_path, notice: "#{label_for(@block)} wurde gespeichert."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @block.destroy
    redirect_to edit_admin_cms_path, notice: "#{label_for(@block)} wurde gelöscht."
  end

  def move
    @block.move!(params[:direction])
    redirect_to edit_admin_cms_path
  end

  private

  def load_block
    @block = CmsBlock.find(params[:id])
  end

  def requested_type
    requested_type_from(params[:block_type])
  end

  def requested_type_from(type)
    type = type.to_s
    CmsBlock.block_types.key?(type) ? type : CmsBlock::SECTION_TYPES.first
  end

  def block_params
    permitted = params.require(:cms_block).permit(
      :is_active, :image_position, :image,
      :title, :content, :button_text, :button_url, :question, :answer
    )
    # An untouched file field submits a blank value, which would otherwise
    # purge the block's existing image.
    permitted.delete(:image) if permitted[:image].blank?
    permitted
  end

  def label_for(block)
    helpers.cms_block_type_label(block.block_type)
  end
end
