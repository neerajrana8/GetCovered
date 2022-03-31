class CreateScheduledActions < ActiveRecord::Migration[6.1]
  def change
    create_table :scheduled_actions do |t|
    
      t.integer :action, null: false # enum
      t.integer :status, null: false, default: 0 # enum
      t.datetime :trigger_time, null: false
      t.jsonb :input
      t.jsonb :output
      t.string :error_messages, array: true, null: false, default: []
      t.datetime :started_at
      t.datetime :ended_at
      
      t.references :actionable, null: true, polymorphic: true
      t.references :parent, null: true

      t.timestamps
      
    end
    
    add_index :scheduled_actions, [:status, :trigger_time, :action]
  end
end
