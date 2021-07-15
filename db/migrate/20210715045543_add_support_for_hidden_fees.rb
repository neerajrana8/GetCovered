class AddSupportForHiddenFees < ActiveRecord::Migration[5.2]
  def change
    add_column :policy_premia, :total_hidden_fee, :integer, null: false, default: 0
    add_column :policy_premia, :total_hidden_tax, :integer, null: false, default: 0
    add_column :policy_premium_items, :hidden, :boolean, null: false, default: false
    add_column :line_items, :hidden, :boolean, null: false, default: false
  end
end
