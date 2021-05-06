class BeefUpCommissionItemAnalyticsFields < ActiveRecord::Migration[5.2]
  def change
    add_column :policy_premium_item_transaction, :analytics_category, :integer, null: false, default: 0
    add_column :line_item_change, :analytics_category, :integer, null: false, default: 0
    add_column :commission_items, :analytics_category, :integer, null: false, default: 0
    add_column :commission_items, :parent_payment_total, :integer, null: true
    
    ::LineItem.analytics_categories.each do |name, value|
      LineItemChange.includes(:line_item).references(:line_items)
                    .where(line_items: { analytics_category: value })
                    .update_all(analytics_category: name)
      PolicyPremiumItemTransaction.all.update_all(analytics_category: 'master_policy_premium')
      CommissionItem.joins("JOIN line_item_changes ON line_item_changes.id = commission_items.reason_id AND commission_items.reason_type = 'LineItemChange'")
                    .joins("JOIN line_items ON line_items.id = line_item_changes.line_item_id")
                    .where(line_items: { analytics_category: value })
                    .update_all(analytics_category: name)
      CommissionItem.where(reason_type: "PolicyPremiumItemTransaction").update_all(analytics_category: 'master_policy_premium')
    end
    
    
  end
end
