class AddCurrentPaymentMethodToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :current_payment_method, :integer
  end
end
