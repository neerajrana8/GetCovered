class AddGenericCoverageStatusToEntries < ActiveRecord::Migration[6.1]
  def change
    add_column :reporting_lease_coverage_entries, :coverage_status, :integer
    add_column :reporting_unit_coverage_entries, :coverage_status, :integer
  end
end
