class CreateInvoiceRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :invoice_runs do |t|
      t.integer :year, null: false
      t.string :subject, null: false
      t.text :message, null: false
      t.jsonb :creditor, null: false, default: {}
      t.references :created_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :idempotency_key, null: false
      t.timestamps
      t.index :idempotency_key, unique: true
      t.check_constraint "year >= 2000 AND year <= 9999", name: "invoice_runs_valid_year"
    end
  end
end
