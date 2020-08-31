class AddExternalityFieldsToPolicyPremia < ActiveRecord::Migration[5.2]
  def change
    add_column :policy_premia, :only_fees_internal, :boolean, default: false
    add_column :policy_premia, :external_fees, :integer, default: 0
    
    add_column :policy_group_premia, :only_fees_internal, :boolean, default: false
    add_column :policy_group_premia, :external_fees, :integer, default: 0
  end
end
