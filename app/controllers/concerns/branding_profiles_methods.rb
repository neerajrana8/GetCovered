module BrandingProfilesMethods
  extend ActiveSupport::Concern

  def import
    branding_profile_import =
      BrandingProfiles::Import.run(branding_profile_params: branding_profile_import_params, agency: @agency)
    if branding_profile_import.valid?
      @branding_profile = branding_profile_import.result
      render :show, status: :ok
    else
      render json: standard_error(:branding_profile_import_fail, nil, branding_profile_import.errors.full_messages),
             status: :unprocessable_entity
    end
  end

  def export
    render json: BrandingProfiles::Export.run!(branding_profile: @branding_profile).to_json, status: :ok
  end
end
