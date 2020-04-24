class AddCollectionTrackingToLineItems < ActiveRecord::Migration[5.2]
  def change
    add_column :line_items, :collected :integer, null: false, default: 0
  end
end
