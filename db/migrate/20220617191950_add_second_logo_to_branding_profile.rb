class AddSecondLogoToBrandingProfile < ActiveRecord::Migration[6.1]
  def change
    add_column :branding_profiles, :second_logo_url, :string
  end
end
