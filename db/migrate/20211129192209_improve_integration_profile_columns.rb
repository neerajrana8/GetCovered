class ImproveIntegrationProfileColumns < ActiveRecord::Migration[5.2]
  def change
    add_column :integration_profiles, :external_context, :string
    remove_index :integration_profiles, name: "index_integration_profiles_on_external_id"
    add_index :integration_profiles, [:integration_id, :external_context, :external_id], unique: true, name: "index_integration_profiles_on_externals"
  end
end
