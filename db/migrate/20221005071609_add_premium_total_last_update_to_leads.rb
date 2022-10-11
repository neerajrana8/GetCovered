class AddPremiumTotalLastUpdateToLeads < ActiveRecord::Migration[6.1]
  def change
    add_column :leads, :premium_last_updated_at, :datetime
  end
end
