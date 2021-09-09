class AddOccupiedToInsurables < ActiveRecord::Migration[5.2]
  def change
    add_column :insurables, :occupied, :boolean, default: false
  end
end
