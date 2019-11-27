class AddTypeOfLossToClaims < ActiveRecord::Migration[5.2]
  def change
    add_column :claims, :type_of_loss, :integer, null: false, default: 0
  end
end
