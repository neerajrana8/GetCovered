class AddCarrierCodeToBillingStrategies < ActiveRecord::Migration[5.2]
  def change
    add_column :billing_strategies, :carrier_code, :string
  end
end
