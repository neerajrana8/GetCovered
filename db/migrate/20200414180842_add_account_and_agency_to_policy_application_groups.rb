class AddAccountAndAgencyToPolicyApplicationGroups < ActiveRecord::Migration[5.2]
  def change
    add_reference :policy_application_groups, :account
    add_reference :policy_application_groups, :agency
  end
end
