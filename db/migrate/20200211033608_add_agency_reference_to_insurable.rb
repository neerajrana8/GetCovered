class AddAgencyReferenceToInsurable < ActiveRecord::Migration[5.2]
  def change
    add_reference :insurables, :agency
  end
end
