class AddAccountIdToCoverageRequirements < ActiveRecord::Migration[6.1]
  def change
    add_column :coverage_requirements, :account_id, :integer, null: true
  end
end
