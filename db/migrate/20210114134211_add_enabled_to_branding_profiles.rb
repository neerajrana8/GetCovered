class AddEnabledToBrandingProfiles < ActiveRecord::Migration[5.2]
  def up
    add_column :branding_profiles, :enabled, :boolean, default: true
  end

  def down
    remove_column :branding_profiles, :enabled
  end
end
