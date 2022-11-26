class AddMinimumLiabilityToInsurables < ActiveRecord::Migration[6.1]
  def change
    add_column :insurables, :minimum_liability, :integer
  end
end
