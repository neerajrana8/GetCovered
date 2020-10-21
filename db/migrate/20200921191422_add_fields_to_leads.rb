class AddFieldsToLeads < ActiveRecord::Migration[5.2]
  def change
    add_reference :leads, :profile
    add_reference :leads, :address
    add_column    :leads, :status, :integer, default: 0
    add_column    :leads, :las_visit, :datetime
  end
end
