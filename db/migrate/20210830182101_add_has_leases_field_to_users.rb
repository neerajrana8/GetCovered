class AddHasLeasesFieldToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :has_leases, :boolean, default: false
  end
end
