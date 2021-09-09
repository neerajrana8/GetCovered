class TweakFinancialSystemMore < ActiveRecord::Migration[5.2]
  def change
    change_column_null :policy_premium_item_transactions, :amount, false
    change_column_null :policy_premium_items, :rounding_error_distribution, false
    remove_column :policy_premium_items, :total_processed
    remove_column :policy_premium_items, :all_received
    remove_column :policy_premium_items, :all_processed
    remove_column :policy_premium_items, :preproration_modifiers
  end
end
