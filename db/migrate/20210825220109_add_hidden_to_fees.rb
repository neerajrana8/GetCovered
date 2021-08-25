class AddHiddenToFees < ActiveRecord::Migration[5.2]
  def change
    add_column :fees, :hidden, :boolean
  end
end
