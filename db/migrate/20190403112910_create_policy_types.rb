class CreatePolicyTypes < ActiveRecord::Migration[5.2]
  def change
    create_table :policy_types do |t|
      t.string :title
      t.string :slug
      t.string :designation
      t.boolean :enabled, :null => false, :default => false

      t.timestamps
    end
  end
end
