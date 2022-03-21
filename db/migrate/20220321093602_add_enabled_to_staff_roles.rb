class AddEnabledToStaffRoles < ActiveRecord::Migration[6.1]
  def change
    add_column :staff_roles, :enabled, :boolean, default: true
  end
end
