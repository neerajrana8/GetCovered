class AddSearchableToAddresses < ActiveRecord::Migration[5.2]
  def change
    add_column :addresses, :searchable, :boolean, default: false
  end
end
