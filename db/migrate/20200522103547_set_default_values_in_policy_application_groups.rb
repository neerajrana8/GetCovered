class SetDefaultValuesInPolicyApplicationGroups < ActiveRecord::Migration[5.2]
  def up
    change_column :policy_application_groups, :auto_pay, :boolean, default: false
    change_column :policy_application_groups, :auto_renew, :boolean, default: false
  end

  def down
    change_column :policy_application_groups, :auto_pay, :boolean, default: nil
    change_column :policy_application_groups, :auto_renew, :boolean, default: nil
  end
end
