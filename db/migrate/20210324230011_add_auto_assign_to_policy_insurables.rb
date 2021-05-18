class AddAutoAssignToPolicyInsurables < ActiveRecord::Migration[5.2]
  def change
    add_column :policy_insurables, :auto_assign, :boolean, default: false
  end
end
