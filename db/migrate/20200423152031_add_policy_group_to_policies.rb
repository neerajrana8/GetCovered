class AddPolicyGroupToPolicies < ActiveRecord::Migration[5.2]
  def change
    add_reference :policies, :policy_group
  end
end
