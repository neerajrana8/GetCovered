class CreateHistories < ActiveRecord::Migration[5.2]
  def change
    create_table :histories do |t|
      t.integer :action, default: 0
      t.json :data, default: {}
      t.references :recordable, polymorphic: true
      t.references :authorable, polymorphic: true

      t.timestamps
    end
  end
end
