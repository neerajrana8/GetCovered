class AddLesseeToLeaseUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :lease_users, :lessee, :boolean, null: false, default: true
  end
end
