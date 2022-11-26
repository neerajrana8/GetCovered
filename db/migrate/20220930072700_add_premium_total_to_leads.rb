class AddPremiumTotalToLeads < ActiveRecord::Migration[6.1]
  def change
    add_column :leads, :premium_total, :integer
  end
end
