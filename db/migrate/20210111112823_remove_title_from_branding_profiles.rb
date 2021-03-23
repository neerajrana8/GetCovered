class RemoveTitleFromBrandingProfiles < ActiveRecord::Migration[5.2]
  def change
    remove_column :branding_profiles, :title
  end
end
