class AddAuthorToHistories < ActiveRecord::Migration[5.2]
  def change
    add_column :histories, :author, :string
  end
end
