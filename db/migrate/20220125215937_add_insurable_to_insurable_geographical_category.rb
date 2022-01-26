class AddInsurableToInsurableGeographicalCategory < ActiveRecord::Migration[6.1]
  def change
    add_reference :insurable_geographical_categories, :insurable, null: true
    add_column :insurable_geographical_categories, :special_usage, :integer
  end
end
