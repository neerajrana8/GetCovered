class CreateGlobalPermissions < ActiveRecord::Migration[5.2]
  def change
    create_table :global_permissions do |t|
      t.jsonb :permissions
      t.bigint :ownerable_id
      t.string :ownerable_type

      t.timestamps
    end
  end
end
