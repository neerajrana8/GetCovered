class AddAddressAndOutOfSystemCarrierTitleToPolicies < ActiveRecord::Migration[5.2]
  def change
    unless Policy.column_names.include?('address', 'out_of_system_carrier_title')
      add_column :policies, :address, :string
      add_column :policies, :out_of_system_carrier_title, :string
    else
      puts 'No need migration already existed'
    end
  end
end
