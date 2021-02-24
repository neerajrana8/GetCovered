class AddBrandingProfileIdToTrackingUrl < ActiveRecord::Migration[5.2]
  def up
    add_column :tracking_urls, :branding_profile_id, :integer

    TrackingUrl.each do |tracking_url|
      tracking_url.update(branding_profile_id: tracking_url&.agency&.branding_profiles&.first&.id)
    end
  end

  def down
    remove_column :tracking_urls, :branding_profile_id
  end
end
