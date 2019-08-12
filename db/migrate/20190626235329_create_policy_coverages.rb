class CreatePolicyCoverages < ActiveRecord::Migration[5.2]
  def change
    create_table :policy_coverages do |t|
      t.string :coverage_type
      t.string :display_title
      t.integer :limit, :default => 0
      t.integer :deductible, :default => 0
      t.boolean :enabled, :null => false, :default => false
      t.datetime :enabled_changed
      t.references :policy
      t.references :policy_quote
      t.references :insurable_rate

      t.timestamps
    end
  end
end
