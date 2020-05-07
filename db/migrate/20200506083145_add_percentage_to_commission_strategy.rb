class AddPercentageToCommissionStrategy < ActiveRecord::Migration[5.2]
  def change
    add_column :commission_strategies, :percentage, :decimal, :precision => 5, :scale => 2
  end
end
