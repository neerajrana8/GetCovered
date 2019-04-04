class CreateModulePermissions < ActiveRecord::Migration[5.2]
  def change
    create_table :module_permissions do |t|
      t.references :application_module
      t.references :permissible, 
        polymorphic: true, 
        index: { :name => "permissible_access_index" }
      t.timestamps
    end
  end
end
