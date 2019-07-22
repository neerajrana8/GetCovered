class CreateLeaseUsers < ActiveRecord::Migration[5.2]
  def change
    create_table :lease_users do |t|
	    t.boolean :primary, default: false
      t.references :lease
      t.references :user

      t.timestamps
    end
  end
end
