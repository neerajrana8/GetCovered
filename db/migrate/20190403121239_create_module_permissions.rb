class CreateModulePermissions < ActiveRecord::Migration[5.2]
  def change
    create_table :module_permissions do |t|
      t.references :application_module
      t.references :permissable, 
        polymorphic: true, 
        index: { :name => "permissable_access_index" }
      t.timestamps
    end
  end
end
