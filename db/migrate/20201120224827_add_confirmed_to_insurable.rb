class AddConfirmedToInsurable < ActiveRecord::Migration[5.2]
  def change
    add_column :insurables, :confirmed, :boolean, null: false, default: true
  end
end
