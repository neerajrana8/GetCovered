class CreateInsurableRates < ActiveRecord::Migration[5.2]
  def change
    create_table :insurable_rates do |t|
      t.string :title
      t.string :schedule
      t.string :sub_schedule
      t.text :description
      t.boolean :liability_only
	    t.integer :number_insured
      t.jsonb :deductibles, default: {}
      t.jsonb :coverage_limits, default: {}
      t.integer :interval, default: 0
      t.integer :premium, default: 0
      t.boolean :activated
      t.date :activated_on
      t.date :deactivated_on
      t.boolean :paid_in_full
      t.references :carrier
      t.references :agency
      t.references :insurable

      t.timestamps
    end
  end
end