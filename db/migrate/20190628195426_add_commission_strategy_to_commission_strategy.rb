class AddCommissionStrategyToCommissionStrategy < ActiveRecord::Migration[5.2]
  def change
    add_reference :commission_strategies, :commission_strategy
  end
end
