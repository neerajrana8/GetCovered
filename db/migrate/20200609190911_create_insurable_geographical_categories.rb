class CreateInsurableGeographicalCategories < ActiveRecord::Migration[5.2]
  def change
    create_table :insurable_geographical_categories do |t|
      t.integer :state
      t.string :counties, array: true
      
      t.references :configurer,
        polymorphic: true
      t.references :carrier_insurable_type

      t.timestamps
    end
  end
end
