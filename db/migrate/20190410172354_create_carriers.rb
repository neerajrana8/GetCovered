class CreateCarriers < ActiveRecord::Migration[5.2]
  def change
    create_table :carriers do |t|
      t.string :title
      t.string :slug
      t.string :call_sign
      t.boolean :syncable, :null => false, :default => false
      t.boolean :rateable, :null => false, :default => false
      t.boolean :quotable, :null => false, :default => false
      t.boolean :bindable, :null => false, :default => false
      t.boolean :verifiable, :null => false, :default => false
      t.boolean :enabled, :null => false, :default => false
      t.jsonb :settings, :null => false, :default => {}

      t.timestamps
    end
  end
end
