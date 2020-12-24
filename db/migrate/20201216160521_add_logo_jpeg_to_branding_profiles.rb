class AddLogoJpegToBrandingProfiles < ActiveRecord::Migration[5.2]
  def change
    add_column :branding_profiles, :logo_jpeg_url, :string
  end
end
