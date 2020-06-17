class CreateChangeRequests < ActiveRecord::Migration[5.2]
  def change
    create_table :change_requests do |t|
      t.text :reason
      t.integer :action, default: 0
      t.string :method
      t.string :field
      t.string :current_value
      t.string :new_value
      t.integer :status, default: 0
      t.datetime :status_changed_on
      t.references :staff, index: true

      t.timestamps
    end
    add_index :change_requests, :action, unique: true
    add_index :change_requests, :status, unique: true
  end
end
