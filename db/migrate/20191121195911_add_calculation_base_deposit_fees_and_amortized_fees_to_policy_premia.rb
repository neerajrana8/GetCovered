class AddCalculationBaseDepositFeesAndAmortizedFeesToPolicyPremia < ActiveRecord::Migration[5.2]
  def change
    add_column :policy_premia, :calculation_base, :integer, :default => 0
    add_column :policy_premia, :deposit_fees, :integer, :default => 0
    add_column :policy_premia, :amortized_fees, :integer, :default => 0
  end
end
