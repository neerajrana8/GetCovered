class AddAccountToLeads < ActiveRecord::Migration[5.2]
  def change
    add_column :leads, :account_id, :integer
  end
end
