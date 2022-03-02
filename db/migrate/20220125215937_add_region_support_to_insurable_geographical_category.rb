class AddRegionSupportToInsurableGeographicalCategory < ActiveRecord::Migration[6.1]
  def change
    add_reference :insurable_geographical_categories, :insurable, null: true
    add_column :insurable_geographical_categories, :special_usage, :integer
    add_column :insurable_geographical_categories, :special_designation, :string
    add_column :insurable_geographical_categories, :special_settings, :jsonb
  end
end
