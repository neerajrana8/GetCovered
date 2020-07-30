class AddCoverageOptionsMutabilityToInsurableRateConfigurations < ActiveRecord::Migration[5.2]
  def change
    add_column :insurable_rate_configurations, :coverage_options_mutability, :jsonb, default: [], null: false
    change_column_default :insurable_rate_configurations, :coverage_options, from: [], to: {}
  end
end
