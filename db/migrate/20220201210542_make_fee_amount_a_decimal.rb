class MakeFeeAmountADecimal < ActiveRecord::Migration[6.1]
  def up
    change_column :fees, :amount, :decimal
  end
  def down
    change_column :fees, :amount, :integer
  end
end
