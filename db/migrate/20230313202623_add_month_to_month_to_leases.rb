class AddMonthToMonthToLeases < ActiveRecord::Migration[6.1]
  def change
    add_column :leases, :month_to_month, :boolean, null: false, default: false
  end
end
