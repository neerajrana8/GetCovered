class AddEstimateToPolicyPremiums < ActiveRecord::Migration[5.2]
  def change
    add_column :policy_premia, :estimate, :integer
  end
end
