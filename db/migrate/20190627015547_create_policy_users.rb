class CreatePolicyUsers < ActiveRecord::Migration[5.2]
  def change
    create_table :policy_users do |t|
      t.boolean :primary, :null => false, :default => false
      t.boolean :spouse, :null => false, :default => false
      t.references :policy_application
      t.references :policy
      t.references :user

      t.timestamps
    end
  end
end
