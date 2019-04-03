class CreateLineItems < ActiveRecord::Migration[5.2]
  def change
    create_table :line_items do |t|
      t.string      :title
      t.integer     :price, default: 0
      t.references  :invoice, index: true
      t.timestamps
    end
  end
end