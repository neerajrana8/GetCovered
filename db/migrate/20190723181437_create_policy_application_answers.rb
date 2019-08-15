class CreatePolicyApplicationAnswers < ActiveRecord::Migration[5.2]
  def change
    create_table :policy_application_answers do |t|
      t.jsonb :data, default: {
	      options: [],
	      desired: nil,
	      answer: nil
      }
      t.integer :section, :null => false, :default => 0
      t.references :policy_application_field
      t.references :policy_application

      t.timestamps
    end
  end
end
