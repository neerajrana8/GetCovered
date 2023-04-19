class CreateCheckedFiles < ActiveRecord::Migration[6.1]
  def change
    create_table :checked_files do |t|
      t.string :name
      t.string :checksum
      t.boolean :processed, default: false
      t.timestamps
    end
  end
end
