class AddBillingStrategyToPolicyApplication < ActiveRecord::Migration[5.2]
  def change
    add_reference :policy_applications, :billing_strategy, foreign_key: false, index: true
  end
end
