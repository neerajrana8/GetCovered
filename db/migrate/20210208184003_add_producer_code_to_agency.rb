class AddProducerCodeToAgency < ActiveRecord::Migration[5.2]
  def change
    add_column :agencies, :producer_code, :string
    add_index :agencies, :producer_code, :unique => true
  end
end
