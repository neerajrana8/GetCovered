class CreateNotes < ActiveRecord::Migration[5.2]
  def change
    create_table :notes do |t|
      t.text :content
      t.string :excerpt
      t.integer :visibility, :null => false, :default => 0
      t.references :staff
      t.references :noteable, polymorphic: true

      t.timestamps
    end
  end
end
