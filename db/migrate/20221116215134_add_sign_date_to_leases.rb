class AddSignDateToLeases < ActiveRecord::Migration[6.1]
  def change
    add_column :leases, :sign_date, :date
  end
end
