class AddDateFieldsToInsurableRateConfigurations < ActiveRecord::Migration[6.1]
  def change
    add_column :insurable_geographical_categories, :irc_cutoffs, :jsonb, null: false, default: {'1' => []}
    add_column :insurable_rate_configurations, :start_date, :date, null: false, default: Date.parse("1 January, 2000")
    add_column :insurable_rate_configurations, :end_date, :date, null: true, default: nil
    change_column_default :insurable_rate_configurations, :start_date, from: Date.parse("1 January, 2000"), to: nil
  end
end
