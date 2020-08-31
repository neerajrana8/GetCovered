class AddCarrierPaymentDataToPolicyQuote < ActiveRecord::Migration[5.2]
  def change
    add_column :policy_quotes, :carrier_payment_data, :jsonb
  end
end
