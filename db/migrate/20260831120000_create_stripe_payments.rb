class CreateStripePayments < ActiveRecord::Migration[8.0]
  def change
    create_table :stripe_payments do |t|
      t.references :participation, null: false, foreign_key: true
      t.references :participation_upgrade, foreign_key: true
      t.string :payment_kind, null: false
      t.string :obligation_key, null: false
      t.integer :attempt, null: false
      t.integer :amount_cents, null: false
      t.string :currency, null: false, default: "chf"
      t.string :status, null: false, default: "pending"
      t.string :idempotency_key, null: false
      t.string :checkout_session_id
      t.text :checkout_url
      t.string :payment_intent_id
      t.datetime :expires_at
      t.datetime :paid_at
      t.string :failure_code
      t.timestamps
    end

    add_index :stripe_payments, :idempotency_key, unique: true
    add_index :stripe_payments, :checkout_session_id, unique: true
    add_index :stripe_payments, :payment_intent_id, unique: true
    add_index :stripe_payments, [ :obligation_key, :attempt ], unique: true
    add_index :stripe_payments, :obligation_key, unique: true,
      where: "status IN ('pending', 'checkout_created', 'processing')", name: "one_active_stripe_payment_per_obligation"
    add_check_constraint :stripe_payments, "amount_cents > 0", name: "stripe_payments_positive_amount"

    create_table :stripe_webhook_events do |t|
      t.string :stripe_event_id, null: false
      t.string :event_type, null: false
      t.string :status, null: false, default: "received"
      t.jsonb :payload, null: false, default: {}
      t.datetime :processed_at
      t.text :processing_error
      t.timestamps
    end

    add_index :stripe_webhook_events, :stripe_event_id, unique: true
  end
end
