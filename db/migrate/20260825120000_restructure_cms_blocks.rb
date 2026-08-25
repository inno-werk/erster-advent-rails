class RestructureCmsBlocks < ActiveRecord::Migration[8.0]
  # The CMS was scaffolded with a generic "content / image / q&a" block set.
  # The frontpage only ever needs four concrete blocks, so the enum is
  # renumbered here and the missing per-block settings are added.
  #
  # old: 0 image_block, 1 content_block, 2 qa_block
  # new: 0 text_image_block, 1 full_image_block, 2 plain_text_block, 3 faq_item
  def up
    add_column :cms_blocks, :image_position, :string, null: false, default: "left"
    change_column_default :cms_blocks, :page, "home"
    change_column_default :cms_blocks, :position, 0

    # Offset first so the 0 <-> 1 swap cannot collide with itself.
    execute "UPDATE cms_blocks SET block_type = block_type + 100"
    execute "UPDATE cms_blocks SET block_type = 1 WHERE block_type = 100"
    execute "UPDATE cms_blocks SET block_type = 0 WHERE block_type = 101"
    execute "UPDATE cms_blocks SET block_type = 3 WHERE block_type = 102"

    add_index :cms_blocks, [ :page, :position ]
  end

  def down
    remove_index :cms_blocks, [ :page, :position ]

    execute "UPDATE cms_blocks SET block_type = block_type + 100"
    execute "UPDATE cms_blocks SET block_type = 1 WHERE block_type = 100"
    execute "UPDATE cms_blocks SET block_type = 0 WHERE block_type = 101"
    execute "UPDATE cms_blocks SET block_type = 2 WHERE block_type = 102"
    execute "UPDATE cms_blocks SET block_type = 2 WHERE block_type = 103"

    change_column_default :cms_blocks, :position, nil
    change_column_default :cms_blocks, :page, nil
    remove_column :cms_blocks, :image_position
  end
end
