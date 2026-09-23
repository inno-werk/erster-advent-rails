class AddPublicContactFlagsToBusinesses < ActiveRecord::Migration[8.0]
  # Existing businesses already show phone and email publicly, so they start
  # opted in; new businesses default to hidden until the member opts in.
  def change
    add_column :businesses, :show_phone_publicly, :boolean, default: true, null: false
    add_column :businesses, :show_email_publicly, :boolean, default: true, null: false
    change_column_default :businesses, :show_phone_publicly, from: true, to: false
    change_column_default :businesses, :show_email_publicly, from: true, to: false
  end
end
