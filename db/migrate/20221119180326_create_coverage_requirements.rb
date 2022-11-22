class CreateCoverageRequirements < ActiveRecord::Migration[6.1]
  def change
    create_table :coverage_requirements do |t|
      t.string :designation
      t.integer :amount
      t.date :start_date
      t.references :insurable, null: false

      t.timestamps
    end
  end
end
