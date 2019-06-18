class CreateBrandingProfiles < ActiveRecord::Migration[5.2]
  def change
    create_table :branding_profiles do |t|
      t.string :title
      t.string :url
      t.boolean :default, :null => false, :default => false
      t.jsonb :styles
      t.references :profileable, polymorphic: true

      t.timestamps
    end
    add_index :branding_profiles, :url, unique: true
  end
end
