class CreatePrintDistributions < ActiveRecord::Migration[8.0]
  def change
    create_table :print_distributions do |t|
      t.integer :year, null: false
      t.date :distribution_on
      t.timestamps
    end
    add_index :print_distributions, :year, unique: true
  end
end
