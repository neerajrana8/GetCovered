class UseCitextForUserEmail < ActiveRecord::Migration[5.2]
  def up
    change_column :users, :email, :citext
  end
  
  def down
    change_column :users, :email, :string
  end
end
