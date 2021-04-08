class AddIndexesForDashboardEntities < ActiveRecord::Migration[5.2]
  def change
    add_index :leads, :tracking_url_id
    add_index :leads, :tracking_url_id
  end
end
