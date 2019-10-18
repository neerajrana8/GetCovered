class CreateAccountUsers < ActiveRecord::Migration[5.2]
  def change
    create_table :account_users do |t|
      t.integer :status, :default => 0
      t.references :account
      t.references :user

      t.timestamps
    end
  end
end
