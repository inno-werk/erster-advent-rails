class CreateSiteSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :site_settings do |t|
      t.string :brand_color, null: false, default: "#52819C"

      t.timestamps
    end
  end
end
