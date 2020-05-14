class AddDeclinedToPolicy < ActiveRecord::Migration[5.2]
  def change
    add_column :policies, :declined, :boolean
  end
end
