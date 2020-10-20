class AddAgencyToLeads < ActiveRecord::Migration[5.2]
  def change
    add_column :leads, :agency_id, :integer, index: true
  end
end
