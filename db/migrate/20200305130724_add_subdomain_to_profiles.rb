class AddSubdomainToProfiles < ActiveRecord::Migration[5.2]
  def change
    add_column :branding_profiles, :subdomain, :string
  end
end
