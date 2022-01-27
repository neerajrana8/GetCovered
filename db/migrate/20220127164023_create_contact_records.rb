class CreateContactRecords < ActiveRecord::Migration[6.1]
  def change
    create_table :contact_records do |t|
      t.integer :direction, default: 0
      t.integer :approach, default: 0
      t.integer :status, default: 1
      t.string :contactable_type
      t.bigint :contactable_id

      t.timestamps
    end

    add_index :contact_records, :contactable_id
  end
end
