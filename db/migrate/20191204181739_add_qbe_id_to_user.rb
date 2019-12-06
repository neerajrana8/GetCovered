class AddQbeIdToUser < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :qbe_id, :string
    add_index :users, :qbe_id, unique: true
  end
end
