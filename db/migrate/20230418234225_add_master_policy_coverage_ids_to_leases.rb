class AddMasterPolicyCoverageIdsToLeases < ActiveRecord::Migration[6.1]
  def change
    add_column :leases, :master_policy_coverage_ids, :bigint, array: true, null: false, default: []
  end
end
