class AddExpandedCoverageToLease < ActiveRecord::Migration[6.1]
  def change
    add_column :leases, :expanded_covered, :jsonb, default: {}
  end
end
