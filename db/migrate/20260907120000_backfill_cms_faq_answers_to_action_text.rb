class BackfillCmsFaqAnswersToActionText < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      INSERT INTO action_text_rich_texts
        (name, body, record_type, record_id, created_at, updated_at)
      SELECT
        'content', cms_blocks.answer, 'CmsBlock', cms_blocks.id,
        CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM cms_blocks
      WHERE cms_blocks.block_type = 3
        AND NULLIF(BTRIM(cms_blocks.answer), '') IS NOT NULL
        AND NOT EXISTS (
          SELECT 1
          FROM action_text_rich_texts
          WHERE action_text_rich_texts.record_type = 'CmsBlock'
            AND action_text_rich_texts.record_id = cms_blocks.id
            AND action_text_rich_texts.name = 'content'
        )
    SQL
  end

  # Keep the copied rich text on rollback so content edited after deployment is
  # not destroyed. The legacy column is retained throughout the rollout.
  def down; end
end
