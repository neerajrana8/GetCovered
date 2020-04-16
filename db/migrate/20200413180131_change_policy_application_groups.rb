class ChangePolicyApplicationGroups < ActiveRecord::Migration[5.2]
  def change
    remove_column :policy_application_groups, :errors_list
    remove_column :policy_application_groups, :title
    add_column    :policy_application_groups, :policy_applications_count, :integer
    add_column    :policy_application_groups, :status, :integer, default: 0
  end
end
