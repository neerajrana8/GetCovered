class AddStatusDisputedAtAndDisputeStatusToPolicyUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :policy_users, :status, :integer, :default => 0
    add_column :policy_users, :disputed_at, :datetime
    add_column :policy_users, :dispute_status, :integer, :default => 0
    add_column :policy_users, :dispute_reason, :text
  end
end
