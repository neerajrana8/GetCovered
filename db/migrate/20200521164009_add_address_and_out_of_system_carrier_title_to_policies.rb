class AddAddressAndOutOfSystemCarrierTitleToPolicies < ActiveRecord::Migration[5.2]
  def self.up
    change_table :policies do |t|
      t.change :address, :string
      t.change :out_of_system_carrier_title, :string
    end
  end
end
