class AddEstPremiumToPolicyQuote < ActiveRecord::Migration[5.2]
  def change
    add_column :policy_quotes, :est_premium, :integer
  end
end
