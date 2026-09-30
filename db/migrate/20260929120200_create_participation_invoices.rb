class CreateParticipationInvoices < ActiveRecord::Migration[8.0]
  def change
    create_table :participation_invoices do |t|
      t.references :invoice_run, null: false, foreign_key: { on_delete: :cascade }
      t.references :participation, null: false, foreign_key: { on_delete: :cascade }
      t.references :participation_upgrade, foreign_key: { on_delete: :nullify }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.integer :year, null: false
      t.string :category, null: false
      t.string :previous_category
      t.integer :amount_cents, null: false
      t.string :recipient_email, null: false
      t.string :recipient_name, null: false
      t.text :recipient_address, null: false
      t.string :status, null: false, default: "queued"
      t.datetime :sent_at
      t.string :error_message
      t.timestamps
      t.index [ :invoice_run_id, :participation_id ], unique: true, name: "one_invoice_per_participation_and_run"
      t.index [ :participation_id, :sent_at ]
      t.check_constraint "amount_cents > 0", name: "participation_invoices_positive_amount"
      t.check_constraint "status IN ('queued', 'sending', 'sent', 'failed', 'cancelled')", name: "participation_invoices_valid_status"
      t.check_constraint "(status = 'sent') = (sent_at IS NOT NULL)", name: "participation_invoices_sent_state"
    end
  end
end
