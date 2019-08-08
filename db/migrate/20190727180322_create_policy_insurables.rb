class CreatePolicyInsurables < ActiveRecord::Migration[5.2]
  def change
    create_table :policy_insurables do |t|
	    t.integer :value, default: 0
      t.boolean :primary, default: false
      t.boolean :current, default: false
      t.references :policy
      t.references :insurable

      t.timestamps
    end
  end
end
