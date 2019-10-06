class AddPolicyApplicationToPolicyRate < ActiveRecord::Migration[5.2]
  def change
    add_reference :policy_rates, :policy_application
  end
end
