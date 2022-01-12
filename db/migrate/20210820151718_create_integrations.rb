class CreateIntegrations < ActiveRecord::Migration[5.2]
  def change
    create_table :integrations do |t|
      t.string :external_id
      t.jsonb :credentials, :default => {}
      t.jsonb :configuration, :default => {}
      t.boolean :enabled, :default => false
      t.references :integratable, polymorphic: true

      t.timestamps
    end
    add_index :integrations, :external_id, unique: true
  end
end
