class BeefUpInsurableGeographicalCategory < ActiveRecord::Migration[5.2]
  def change
    add_column :zip_codes, :insurable_geographical_categories, :string, array: true
    add_column :cities, :insurable_geographical_categories, :string, array: true
  end
end
