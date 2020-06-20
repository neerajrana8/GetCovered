class AddCoverageSelectionsToPolicyApplications < ActiveRecord::Migration[5.2]
  def change
    add_column :policy_applications, :coverage_selections, :jsonb
  end
end
