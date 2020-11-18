class RemakeLeadFields < ActiveRecord::Migration[5.2]
  def change
    rename_column :leads, :last_page_visited, :last_visited_page
    remove_column :leads, :profile_id
    remove_column :leads, :address_id
    remove_column :leads, :campaign_source
    add_column :leads, :tracking_url_id, :integer, index: true
  end
end
