class SetInsurableNullConstraint < ActiveRecord::Migration[6.1]
  def change
    change_column :coverage_requirements, :insurable_id, :integer, null: true
  end
end
