class CreateTags < ActiveRecord::Migration[5.2]
  def change
    create_table :tags do |t|
      t.string :title
      t.text :description

      t.timestamps
    end
    
    add_index :tags, :title, unique: true # for now... we may want a GIN or something weird here at some point
  end
end
