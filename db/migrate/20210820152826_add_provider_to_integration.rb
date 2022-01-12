class AddProviderToIntegration < ActiveRecord::Migration[5.2]
  def change
    add_column :integrations, :provider, :integer, :default => 0
  end
end
