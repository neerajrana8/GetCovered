class AddRenewalFieldsToLease < ActiveRecord::Migration[6.1]
  def change
    add_column :leases, :renewal_date, :date
    add_column :leases, :renewal_count, :integer, :default => 0
    add_column :leases, :external_status, :string
  end
end
