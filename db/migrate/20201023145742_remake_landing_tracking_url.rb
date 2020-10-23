class RemakeLandingTrackingUrl < ActiveRecord::Migration[5.2]
  def change
    change_column :tracking_urls, :landing_page, :string
  end
end
