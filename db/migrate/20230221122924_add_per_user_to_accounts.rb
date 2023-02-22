class AddPerUserToAccounts < ActiveRecord::Migration[6.1]
  def change
    add_column :accounts, :per_user_tracking, :boolean, :default => false
  end
end
