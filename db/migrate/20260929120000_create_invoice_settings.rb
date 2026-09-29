class CreateInvoiceSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :invoice_settings do |t|
      t.string :creditor_name, null: false
      t.string :street, null: false
      t.string :building_number, null: false, default: ""
      t.string :postal_code, null: false
      t.string :town, null: false
      t.string :country, null: false, default: "CH"
      t.string :iban, null: false
      t.string :bank_name, null: false
      t.text :letterhead, null: false, default: ""
      t.timestamps
    end
  end
end
