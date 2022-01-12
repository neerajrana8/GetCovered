class CreateIntegrationProfiles < ActiveRecord::Migration[5.2]
  def change
    create_table :integration_profiles do |t|
      t.string :external_id
      t.jsonb :configuration, :default => {}
      t.boolean :enabled, :default => false
      t.references :integration
      t.references :profileable, polymorphic: true,
                                      index: { name: :index_integration_profiles_on_profileable }

      t.timestamps
    end
    add_index :integration_profiles, :external_id, unique: true
  end
end
