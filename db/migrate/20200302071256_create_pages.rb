class CreatePages < ActiveRecord::Migration[5.2]
  def change
    create_table :pages do |t|
      t.text :content
      t.string :title
      t.references :agency, index: true
      t.timestamps
    end
    add_column :branding_profiles, :logo_url, :string
    add_column :branding_profiles, :footer_logo_url, :string
    create_table :branding_profile_attributes do |t|
      t.string :name
      t.string :value
      t.string :attribute_type
      t.references :branding_profile, index: true
      t.timestamps
    end
  end
end
