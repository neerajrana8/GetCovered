class AddGlobalDefaultToBrandingProfile < ActiveRecord::Migration[5.2]
  def up
    add_column :branding_profiles, :global_default, :boolean, default: false, null: false
    BrandingProfile.where(title: 'GetCovered').order(:id).first&.update(global_default: true)
  end

  def down
    remove_column  :branding_profiles, :global_default
  end
end
