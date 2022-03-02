class AddAltuidToUser < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :altuid, :string
  end
end
