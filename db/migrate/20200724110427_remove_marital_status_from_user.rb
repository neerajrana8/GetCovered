class RemoveMaritalStatusFromUser < ActiveRecord::Migration[5.2]
  def change
    remove_column :users, :marital_status
  end
end
