class CreateApplicationModules < ActiveRecord::Migration[5.2]
  def change
    create_table :application_modules do |t|
      t.string :title
      t.string :slug
      t.jsonb :nodes, default: {}
      t.boolean :enabled

      t.timestamps
    end
  end
end
