class RemovePremiumTaxEstFeesAndTotalPremiumFromPolicyApplications < ActiveRecord::Migration[5.2]
  def change
    remove_column :policy_quotes, :premium
    remove_column :policy_quotes, :tax
    remove_column :policy_quotes, :est_fees
    remove_column :policy_quotes, :total_premium
  end
end
