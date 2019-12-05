class AddAutoPayAndAutoRenewToPolicyApplications < ActiveRecord::Migration[5.2]
  def change
    add_column :policy_applications, :auto_renew, :boolean, :default => true
    add_column :policy_applications, :auto_pay, :boolean, :default => true
  end
end
