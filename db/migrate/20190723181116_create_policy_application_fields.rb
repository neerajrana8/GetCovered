class CreatePolicyApplicationFields < ActiveRecord::Migration[5.2]
  def change
    create_table :policy_application_fields do |t|
      t.string :title
      t.integer :section
      t.integer :answer_type
      t.string :default_answer
      t.string :desired_answer
      t.jsonb :answer_options
      t.boolean :enabled
      t.integer :order_position
      t.references :policy_application_field
      t.references :policy_type
      t.references :carrier

      t.timestamps
    end
  end
end
