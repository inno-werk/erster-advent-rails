class RenameSuesswarenBusinessCategory < ActiveRecord::Migration[8.0]
  # Business categories are stored by label, so the Swiss spelling change in
  # BUSINESS_CATEGORIES must be applied to existing rows as well. The legacy
  # users.category copy of the label is renamed alongside it.
  def up
    rename_category("Süßwaren", "Süsswaren")
  end

  def down
    rename_category("Süsswaren", "Süßwaren")
  end

  private

  # Replaces the element in place, keeps order, and drops a duplicate if a row
  # somehow already carries both spellings.
  def rename_category(from, to)
    execute <<~SQL.squish
      UPDATE businesses
      SET categories = (
        SELECT COALESCE(jsonb_agg(value ORDER BY first_position), '[]'::jsonb)
        FROM (
          SELECT value, MIN(position) AS first_position
          FROM (
            SELECT
              CASE WHEN element = to_jsonb(#{quote(from)}::text) THEN to_jsonb(#{quote(to)}::text) ELSE element END AS value,
              position
            FROM jsonb_array_elements(businesses.categories) WITH ORDINALITY AS elements(element, position)
          ) renamed
          GROUP BY value
        ) deduplicated
      )
      WHERE categories @> jsonb_build_array(#{quote(from)}::text)
    SQL

    execute "UPDATE users SET category = #{quote(to)} WHERE category = #{quote(from)}"
  end
end
