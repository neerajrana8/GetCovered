class AddLeaseViolationOnlytoMasterPolicyConfiguration < ActiveRecord::Migration[6.1]
  def change
    add_column :master_policy_configurations, :lease_violation_only, :boolean, default: true
  end
end
