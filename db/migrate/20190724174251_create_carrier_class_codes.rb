class CreateCarrierClassCodes < ActiveRecord::Migration[5.2]
  def change
    create_table :carrier_class_codes do |t|
      t.integer :external_id
      t.string :major_category
      t.string :sub_category
      t.string :class_code
      t.boolean :appetite, default: false
      t.string :search_value
      t.string :sic_code
      t.string :eq
      t.string :eqsl
      t.string :industry_program
      t.string :naics_code
      t.string :state_code
      t.boolean :enabled, default: false
      t.references :carrier
      t.references :policy_type

      t.timestamps
    end
    add_index :carrier_class_codes, :class_code
  end
end
