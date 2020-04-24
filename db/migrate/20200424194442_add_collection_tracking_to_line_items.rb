class AddCollectionTrackingToLineItems < ActiveRecord::Migration[5.2]
  def change
    add_column :line_items, :collected, :integer, null: false, default: 0
    add_column :refunds, :by_line_item, :jsonb
    ::Refund.all.each{|r| r.send(set_line_item_refunds); r.save }
    change_column_null :refunds, :by_line_item, false
  end
end
