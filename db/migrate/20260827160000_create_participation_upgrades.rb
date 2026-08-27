class CreateParticipationUpgrades < ActiveRecord::Migration[8.0]
  def change
    create_table :participation_upgrades do |t|
      t.references :participation, null: false, foreign_key: true
      t.string :previous_category, null: false
      t.integer :previous_amount_cents, null: false
      t.string :category, null: false
      t.integer :amount_cents, null: false
      t.integer :difference_cents, null: false
      t.string :payment_status, null: false, default: "pending"
      t.datetime :paid_at
      t.timestamps
    end
    add_index :participation_upgrades, :participation_id, unique: true,
      where: "payment_status = 'pending'", name: "one_pending_upgrade_per_participation"
    add_check_constraint :participation_upgrades,
      "previous_amount_cents >= 0 AND difference_cents > 0 AND amount_cents = previous_amount_cents + difference_cents",
      name: "participation_upgrades_valid_difference"
    add_check_constraint :participation_upgrades,
      "(payment_status = 'pending' AND paid_at IS NULL) OR (payment_status = 'paid' AND paid_at IS NOT NULL)",
      name: "participation_upgrades_payment_state"
  end
end
