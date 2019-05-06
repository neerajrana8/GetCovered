class DropSuperAdmin < ActiveRecord::Migration[5.2]
  def up
    drop_table :super_admins
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
