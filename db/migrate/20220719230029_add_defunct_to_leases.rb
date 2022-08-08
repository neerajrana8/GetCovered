class AddDefunctToLeases < ActiveRecord::Migration[6.1]
  def change
    add_column :leases, :defunct, :boolean, null: false, default: false
  end
end
