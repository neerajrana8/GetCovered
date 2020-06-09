class CreateInsurableGeographicalCategories < ActiveRecord::Migration[5.2]
  def change
    create_table :insurable_geographical_categories do |t|
      t.string :city, array: true
      t.string :county, array: true
      t.string :zip_code, array: true
      t.integer :state, array: true
      
      t.references :carrier_insurable_type

      t.timestamps
    end
  end
end
