class AddParticipationAndPrintMaterials < ActiveRecord::Migration[8.0]
  def change
    create_table :participations do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :year, null: false
      t.string :category, null: false
      t.integer :amount_cents, null: false
      t.string :payment_status, null: false, default: "pending"
      t.datetime :selected_at, null: false
      t.datetime :paid_at
      t.string :payment_provider
      t.string :payment_reference
      t.timestamps
    end
    add_index :participations, [ :user_id, :year ], unique: true
    add_check_constraint :participations, "year BETWEEN 2000 AND 9999", name: "participations_valid_year"
    add_check_constraint :participations, "category IN ('leist_member', 'non_leist_member', 'no_listing')", name: "participations_valid_category"
    add_check_constraint :participations, "amount_cents >= 0", name: "participations_nonnegative_amount"
    add_check_constraint :participations, "(payment_status = 'pending' AND paid_at IS NULL) OR (payment_status = 'paid' AND paid_at IS NOT NULL)", name: "participations_payment_state"

    create_table :print_products do |t|
      t.string :title, null: false
      t.text :description, null: false
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0
      t.string :seed_key
      t.timestamps
    end
    add_index :print_products, :seed_key, unique: true
    add_check_constraint :print_products, "position >= 0", name: "print_products_nonnegative_position"

    create_table :print_orders do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :year, null: false
      t.timestamps
    end
    add_index :print_orders, [ :user_id, :year ], unique: true
    add_check_constraint :print_orders, "year BETWEEN 2000 AND 9999", name: "print_orders_valid_year"

    create_table :print_order_items do |t|
      t.references :print_order, null: false, foreign_key: true
      t.references :print_product, null: false, foreign_key: true
      t.integer :quantity, null: false
      t.timestamps
    end
    add_index :print_order_items, [ :print_order_id, :print_product_id ], unique: true
    add_check_constraint :print_order_items, "quantity > 0", name: "print_order_items_positive_quantity"
  end
end
