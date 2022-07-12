class CreateStaffRoles < ActiveRecord::Migration[6.1]
  def change
    create_table :staff_roles do |t|
      t.integer :role, default: 0
      t.boolean :primary, default: false
      t.belongs_to :staff, null: false, foreign_key: true
      t.string :organizable_type
      t.bigint :organizable_id

      t.index %w[organizable_type organizable_id], name: "index_staff_roles_on_organizable_type_and_organizable_id"

      t.timestamps
    end
  end
end
