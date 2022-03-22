class AddForcePlacedToPolicy < ActiveRecord::Migration[6.1]
  def change
    add_column :policies, :force_placed, :boolean
  end
end
