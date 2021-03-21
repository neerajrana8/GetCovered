class CreateInsurableData < ActiveRecord::Migration[5.2]
  def change
    create_table :insurable_data do |t|
      t.references :insurable, index: true
      t.integer :uninsured_units
      t.integer :total_units
      t.integer :expiring_policies

      t.timestamps
    end
  end
end
