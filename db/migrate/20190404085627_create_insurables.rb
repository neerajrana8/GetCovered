class CreateInsurables < ActiveRecord::Migration[5.2]
  def change
    create_table :insurables do |t|
      t.string :title
      t.string :slug
      t.boolean :enabled, default: false
      t.references :account
      t.references :insurable_type
      t.references :insurable
      t.integer :category, default: 0
      t.boolean :covered, default: false

      t.timestamps
    end
  end
end