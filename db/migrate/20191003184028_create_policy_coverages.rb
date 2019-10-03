class CreatePolicyCoverages < ActiveRecord::Migration[5.2]
  def change
    create_table :policy_coverages do |t|
      t.string :title
      t.string :designation
      t.integer :limit, default: 0
      t.integer :deductible, default: 0
      t.references :policy, foreign_key: true
      t.references :policy_application, foreign_key: true

      t.timestamps
    end
  end
end
