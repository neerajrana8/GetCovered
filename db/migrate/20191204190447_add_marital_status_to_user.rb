class AddMaritalStatusToUser < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :marital_status, :integer, :default => 0
  end
end
