class AddMinimumLiabilityToAccounts < ActiveRecord::Migration[6.1]
  def change
    add_column :accounts, :minimum_liability, :integer
  end
end
