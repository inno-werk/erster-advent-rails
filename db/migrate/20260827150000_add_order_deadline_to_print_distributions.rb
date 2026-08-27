class AddOrderDeadlineToPrintDistributions < ActiveRecord::Migration[8.0]
  def change
    add_column :print_distributions, :order_deadline_on, :date
  end
end
