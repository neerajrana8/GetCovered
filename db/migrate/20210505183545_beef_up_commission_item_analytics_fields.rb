class BeefUpCommissionItemAnalyticsFields < ActiveRecord::Migration[5.2]
  def up
    add_column :policy_premium_item_transaction, :analytics_category, :integer, null: false, default: 0
    add_column :line_item_change, :analytics_category, :integer, null: false, default: 0
    add_column :commission_items, :analytics_category, :integer, null: false, default: 0
    add_column :commission_items, :parent_payment_total, :integer, null: true
  
    PolicyPremiumItemTransaction.all.update_all(analytics_category: 'master_policy_premium')
    ActiveRecord::Base.connection.execute("UPDATE line_item_changes SET analytics_category = line_items.analytics_category FROM line_items WHERE line_item_changes.line_item_id = line_items.id")
    ActiveRecord::Base.connection.execute("UPDATE commission_items SET (analytics_category, parent_payment_total) = (policy_premium_item_transactions.analytics_category, policy_premium_item_transactions.amount) FROM policy_premium_item_transactions WHERE commission_items.reason_type = 'PolicyPremiumItemTransaction' AND commission_items.reason_id = policy_premium_item_transactions.id")
    ActiveRecord::Base.connection.execute("UPDATE commission_items SET (analytics_category, parent_payment_total) = (line_item_changes.analytics_category, line_item_changes.amount) FROM line_item_changes WHERE commission_items.reason_type = 'LineItemChange' AND commission_items.reason_id = line_item_changes.id")
  end
  
  def down
    remove_column :policy_premium_item_transaction, :analytics_category
    remove_column :line_item_change, :analytics_category
    remove_column :commission_items, :analytics_category
    remove_column :commission_items, :parent_payment_total
  end
end
