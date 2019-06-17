class CreateFees < ActiveRecord::Migration[5.2]
  def change
    create_table :fees do |t|
      t.string :title
      t.string :slug
      t.integer :amount, :null => false, :default => 0
      t.integer :type, :null => false, :default => 0
      t.boolean :per_payment, :null => false, :default => false
      t.boolean :enabled, :null => false, :default => false
      t.references :assignable, polymorphic: true
      t.references :ownerable, polymorphic: true

      t.timestamps
    end
  end
end
