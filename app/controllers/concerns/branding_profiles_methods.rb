module BrandingProfilesMethods
  extend ActiveSupport::Concern

  def import
    file = params[:input_file].open
    branding_profile_import =
      BrandingProfiles::Import.run(branding_profile_params: JSON.parse(file.read), agency: @agency)
    if branding_profile_import.valid?
      @branding_profile = branding_profile_import.result
      render :show, status: :ok
    else
      render json: standard_error(:branding_profile_import_fail, nil, branding_profile_import.errors.full_messages),
             status: :unprocessable_entity
    end
  end

  def export
    result = BrandingProfiles::Export.run!(branding_profile: @branding_profile).to_json
    send_data result,
              filename: "branding-profile-#{@branding_profile.profileable_type.underscore.split('/').last}-#{Date.today}.json",
              status: :ok
  end
end
