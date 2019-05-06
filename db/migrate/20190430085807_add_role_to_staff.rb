class AddRoleToStaff < ActiveRecord::Migration[5.2]
  def change
    add_column :staffs, :role, :integer, default: 0

    add_index :staffs, :role
  end
end
