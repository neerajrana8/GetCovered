class CreateClaims < ActiveRecord::Migration[5.2]
  def change
    create_table :claims do |t|
      t.string :subject
      t.text :description
      t.datetime :time_of_loss
      t.integer :status, default: 0
      t.references :claimant,
        polymorphic: true
      t.references :insurable
      t.references :policy

      t.timestamps
    end
  end
end
