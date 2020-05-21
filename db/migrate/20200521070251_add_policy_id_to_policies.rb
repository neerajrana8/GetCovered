class AddPolicyIdToPolicies < ActiveRecord::Migration[5.2]
  def change
    add_reference :policies, :policy, index: true
  end
end
