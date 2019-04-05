class CreateLeaseTypes < ActiveRecord::Migration[5.2]
  def change
    create_table :lease_types do |t|
      t.string      :title
      t.boolean     :enabled, default: false
      t.timestamps
    end
  end
end