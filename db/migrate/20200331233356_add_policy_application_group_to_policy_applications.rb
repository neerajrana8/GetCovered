class AddPolicyApplicationGroupToPolicyApplications < ActiveRecord::Migration[5.2]
  def change
    add_reference :policy_applications, :policy_application_group, index: true
  end
end
