class RemoveTrackingUrlField < ActiveRecord::Migration[5.2]
  def change
    remove_column :tracking_urls, :tracking_url
  end
end
