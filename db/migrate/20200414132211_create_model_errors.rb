class CreateModelErrors < ActiveRecord::Migration[5.2]
  def change
    create_table :model_errors do |t|
      t.references :model, polymorphic: true, index: true
      t.string :type
      t.jsonb :information
      t.timestamps
    end
  end
end
