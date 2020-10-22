class AddFieldsToLead < ActiveRecord::Migration[5.2]
  def change
    rename_column :leads, :las_visit, :last_visit
    add_column :leads, :last_page_visited, :string
    add_column :leads, :campaign_source, :string
  end
end
