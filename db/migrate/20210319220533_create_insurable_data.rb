class CreateInsurableData < ActiveRecord::Migration[5.2]
  def up
    create_table :insurable_data do |t|
      t.references :insurable, index: true
      t.integer :uninsured_units
      t.integer :total_units
      t.integer :expiring_policies

      t.timestamps
    end

    Insurable.all.each(&:refresh_insurable_data)
  end

  def down
    drop_table :insurable_data
  end
end
