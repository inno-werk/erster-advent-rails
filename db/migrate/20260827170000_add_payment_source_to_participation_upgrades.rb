class AddPaymentSourceToParticipationUpgrades < ActiveRecord::Migration[8.0]
  def change
    add_column :participation_upgrades, :payment_provider, :string
    add_column :participation_upgrades, :payment_reference, :string
  end
end
