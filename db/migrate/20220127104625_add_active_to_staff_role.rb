class AddActiveToStaffRole < ActiveRecord::Migration[6.1]
  def change
    add_column :staff_roles, :active, :boolean, default: false
  end
end
