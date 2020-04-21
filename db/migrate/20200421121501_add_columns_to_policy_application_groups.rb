class AddColumnsToPolicyApplicationGroups < ActiveRecord::Migration[5.2]
  def change
    add_column :policy_application_groups, :effective_date, :date
    add_column :policy_application_groups, :expiration_date, :date

    add_reference :policy_application_groups, :billing_strategy
    add_reference :policy_application_groups, :policy_group
    add_reference :policy_application_groups, :carrier
    add_reference :policy_application_groups, :policy_type
  end
end
