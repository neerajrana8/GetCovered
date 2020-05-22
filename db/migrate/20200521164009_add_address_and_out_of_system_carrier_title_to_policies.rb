class AddAddressAndOutOfSystemCarrierTitleToPolicies < ActiveRecord::Migration[5.2]
  def change
    add_column :policies, :address, :string
    add_column :policies, :out_of_system_carrier_title, :string
  end
end
