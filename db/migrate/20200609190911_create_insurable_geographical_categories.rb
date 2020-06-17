class CreateInsurableGeographicalCategories < ActiveRecord::Migration[5.2]
  def change
    create_table :insurable_geographical_categories do |t|
      t.integer :state, null: true
      t.string :counties, array: true, null: true

      t.timestamps
    end
  end
end
