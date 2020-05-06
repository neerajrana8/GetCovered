class AddDefaultToPercentage < ActiveRecord::Migration[5.2]
  def change
    change_column :commission_strategies, :percentage, :decimal, default: 0.00, :precision => 5, :scale => 2
  end
end
