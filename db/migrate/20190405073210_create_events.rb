class CreateEvents < ActiveRecord::Migration[5.2]
  def change
    create_table :events do |t|
      t.integer :verb, default: 0
      t.integer :format, default: 0
      t.integer :interface, default: 0
      t.integer :status, default: 0
      t.string :process
      t.string :endpoint
      t.datetime :started
      t.datetime :completed
      t.text :request
      t.text :response
      t.references :eventable, 
        polymorphic: true

      t.timestamps
    end
  end
end
