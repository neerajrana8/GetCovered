class AddPolicyGroupToPolicyGroupPremia < ActiveRecord::Migration[5.2]
  def change
    add_reference :policy_group_premia, :policy_group
  end
end
