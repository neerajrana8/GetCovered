class AddBrandingProfileToLeads < ActiveRecord::Migration[5.2]
  def change
    add_column :leads, :branding_profile_id, :integer
  end
end
