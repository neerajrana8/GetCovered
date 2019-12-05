class AddCarrierBaseToPolicyPremium < ActiveRecord::Migration[5.2]
  def change
    add_column :policy_premia, :carrier_base, :integer, :default => 0
  end
end
