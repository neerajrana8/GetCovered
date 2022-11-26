class AddDatesToLeaseUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :lease_users, :moved_in_at, :date, default: nil
    add_column :lease_users, :moved_out_at, :date, default: nil
  end
end
