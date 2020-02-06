class AddSpecialPremiumAndIncludeSpecialPremiumToPolicyPremium < ActiveRecord::Migration[5.2]
  def change
    add_column :policy_premia, :special_premium, :integer, :default => 0
    add_column :policy_premia, :include_special_premium, :boolean, :default => false
  end
end
