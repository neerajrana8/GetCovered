class CreateModifiers < ActiveRecord::Migration[5.2]
  def change
    create_table :modifiers do |t|
      t.integer :strategy
      t.float :amount
      t.integer :tier, default: 0
      t.integer :condition, default: 0
      t.references :invoice

      t.timestamps
    end
  end
end
