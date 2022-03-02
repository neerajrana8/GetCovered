class AddNewCoverageOptionsToPolicyCoverage < ActiveRecord::Migration[6.1]
  def change
    add_column :policy_coverages, :aggregate_limit, :integer
    add_column :policy_coverages, :external_payments_limit, :integer
    add_column :policy_coverages, :limit_used, :integer
  end
end
