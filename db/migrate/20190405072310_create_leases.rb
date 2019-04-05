class CreateLeases < ActiveRecord::Migration[5.2]
  def change
    create_table :leases do |t|
	    t.string :reference, 
        index: { 
          :name => "lease_reference", 
          :unique => true 
        }
      t.date :start_date
      t.date :end_date
      t.string :type
      t.integer :status, default: 0
      t.boolean :covered, default: false
      t.references :unit
      t.references :account

      t.timestamps
    end
  end
end
