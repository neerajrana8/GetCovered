class AddSecondFooterLogoToBrandingProfile < ActiveRecord::Migration[6.1]
  def change
    add_column :branding_profiles, :second_footer_logo_url, :string
  end
end
