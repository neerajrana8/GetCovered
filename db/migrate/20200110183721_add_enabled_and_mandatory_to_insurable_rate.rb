class AddEnabledAndMandatoryToInsurableRate < ActiveRecord::Migration[5.2]
  def change
    add_column :insurable_rates, :enabled, :boolean, :default => true
    add_column :insurable_rates, :mandatory, :boolean, :default => false
  end
end
