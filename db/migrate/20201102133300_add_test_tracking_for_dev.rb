class AddTestTrackingForDev < ActiveRecord::Migration[5.2]
  def change
    leads = Lead.where(last_visit: '2020-10-01'..'2020-10-30')
    agency = Agency.find_by(title: "Get Covered")
    tr_url = TrackingUrl.create!(campaign_source: "test_s", campaign_medium: "test_m", campaign_term: "test_t", campaign_name: 'Test Campaign' ,agency_id: agency.id, landing_page: "rent_guarantee")
    leads.update_all(tracking_url_id: tr_url.id)
  end
end
