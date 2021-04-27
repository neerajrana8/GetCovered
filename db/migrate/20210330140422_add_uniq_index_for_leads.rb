class AddUniqIndexForLeads < ActiveRecord::Migration[5.2]
  def change
    add_index :leads, :identifier, unique: true
  end
end
