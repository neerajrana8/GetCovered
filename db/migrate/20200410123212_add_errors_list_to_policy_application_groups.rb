class AddErrorsListToPolicyApplicationGroups < ActiveRecord::Migration[5.2]
  def change
    add_column :policy_application_groups, :errors_list, :jsonb
  end
end
