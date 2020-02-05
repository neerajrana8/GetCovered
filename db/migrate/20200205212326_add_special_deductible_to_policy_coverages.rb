class AddSpecialDeductibleToPolicyCoverages < ActiveRecord::Migration[5.2]
  def change
    add_column :policy_coverages, :special_deductible, :integer
  end
end
