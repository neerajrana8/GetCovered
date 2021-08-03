class AddBrandingProfileToLeadEvents < ActiveRecord::Migration[5.2]
  def change
    add_column :lead_events, :branding_profile_id, :integer
  end
end
