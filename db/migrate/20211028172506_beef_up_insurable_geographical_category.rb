class BeefUpInsurableGeographicalCategory < ActiveRecord::Migration[5.2]
  def change
    add_column :insurable_geographical_categories, :zip_codes, :string, array: true
    add_column :insurable_geographical_categories, :cities, :string, array: true
  end
end
