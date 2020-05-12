class AddCardDataToPaymentMethods < ActiveRecord::Migration[5.2]
  def change
    add_column :payment_profiles, :card, :jsonb
  end
end
