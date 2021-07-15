class AddSupportForHiddenFees < ActiveRecord::Migration[5.2]
  def up
    add_column :policy_premia, :total_hidden_fee, :integer, null: false, default: 0
    add_column :policy_premia, :total_hidden_tax, :integer, null: false, default: 0
    add_column :policy_premium_items, :hidden, :boolean, null: false, default: false
    add_column :line_items, :hidden, :boolean, null: false, default: false
    
    PolicyPremiumItem.where(title: "Policy Fee").each do |ppi|
      ppi.policy_premium.update_columns(total_hidden_fee: ppi.original_total_due)
      ppi.line_items.update_all(hidden: true)
      ppi.update_columns(hidden: true)
    end
  end
  
  def down
    remove_column :line_items, :hidden
    remove_column :policy_premium_items, :hidden
    remove_column :policy_premia, :total_hidden_tax
    remove_column :policy_premia, :total_hidden_fee
  end
end
