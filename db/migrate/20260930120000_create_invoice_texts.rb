class CreateInvoiceTexts < ActiveRecord::Migration[8.0]
  def change
    create_table :invoice_texts do |t|
      t.integer :year, null: false
      t.string :subject, null: false
      t.text :message, null: false
      t.references :updated_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.timestamps
      t.index :year, unique: true
      t.check_constraint "year >= 2000 AND year <= 9999", name: "invoice_texts_valid_year"
    end
  end
end
