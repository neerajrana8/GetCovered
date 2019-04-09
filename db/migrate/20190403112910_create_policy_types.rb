class CreatePolicyTypes < ActiveRecord::Migration[5.2]
  def change
    create_table :policy_types do |t|
      t.string :title
      t.integer :slug
      t.jsonb :defaults, default: {
        coverage_limits: {},
        deductibles: {},
        options: {}
      }
      t.boolean :enabled

      t.timestamps
    end
  end
end
