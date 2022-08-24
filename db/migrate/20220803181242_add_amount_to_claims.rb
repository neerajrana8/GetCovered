class AddAmountToClaims < ActiveRecord::Migration[6.1]
  def change
    add_column :claims, :amount, :integer
  end
end
