class FixPpitTable < ActiveRecord::Migration[5.2]
  def change
    rename_table :policy_premium_item_transaction, :policy_premium_item_transactions
    rename_table :policy_premium_item_transaction_membership, :policy_premium_item_transaction_memberships
  end
end
