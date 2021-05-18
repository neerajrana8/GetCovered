class AddOccupiableToInsurableTypes < ActiveRecord::Migration[5.2]
  class InsurableType < ActiveRecord::Base
    self.table_name = 'insurable_types'
  end

  def up
    add_column :insurable_types, :occupiable, :boolean, default: false

    InsurableType.where(title: ['Residential Unit', 'Commercial Unit']).update_all(occupiable: true)
  end

  def down
    remove_column :insurable_types, :occupiable
  end
end
