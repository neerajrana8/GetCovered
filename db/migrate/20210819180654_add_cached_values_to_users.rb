class AddCachedValuesToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :has_existing_policies, :boolean, default: false
    add_column :users, :has_current_leases, :boolean, default: false
  end
end
