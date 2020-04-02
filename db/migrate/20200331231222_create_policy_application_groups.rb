class CreatePolicyApplicationGroups < ActiveRecord::Migration[5.2]
  def change
    create_table :policy_application_groups do |t|
      t.string :title
      t.timestamps
    end
  end
end
