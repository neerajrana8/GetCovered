class AddRenewalStatusToPolicy < ActiveRecord::Migration[6.1]
  def change
    add_column :policies, :renewal_status, :integer, :default => 0
  end
end
