class CreateLeaseTypePolicyTypes < ActiveRecord::Migration[5.2]
  def change
    create_table :lease_type_policy_types do |t|
      t.boolean       :enabled, default: true
      t.references    :lease_type
      t.references    :policy_type
      t.timestamps
    end
  end
end