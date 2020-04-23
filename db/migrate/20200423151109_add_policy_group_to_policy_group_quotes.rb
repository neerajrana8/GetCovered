class AddPolicyGroupToPolicyGroupQuotes < ActiveRecord::Migration[5.2]
  def change
    add_reference :policy_group_quotes, :policy_group
  end
end
