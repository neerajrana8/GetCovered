class AddFieldsToLineItem < ActiveRecord::Migration[5.2]
  def change
    add_column :line_items, :refundability, :integer, null: false
    
  end
end
