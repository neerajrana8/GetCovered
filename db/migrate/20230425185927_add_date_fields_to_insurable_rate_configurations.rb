class AddDateFieldsToInsurableRateConfigurations < ActiveRecord::Migration[6.1]
  def change
    add_column :insurable_rate_configurations, :start_date, :date, null: false, default: Date.parse("1 January, 2000")
    add_column :insurable_rate_configurations, :end_date, :date, null: false, default: Date.parse("1 January, 2024")
    change_column_default :insurable_rate_configurations, :start_date, from: Date.parse("1 January, 2000"), to: nil
    change_column_default :insurable_rate_configurations, :end_date, from: Date.parse("1 January, 2024"), to: nil
  end
end
