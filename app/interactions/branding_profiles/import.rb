module BrandingProfiles
  class Import < ActiveInteraction::Base
    hash :branding_profile_params, strip: false
    object :agency

    def execute
      update_url if BrandingProfile.where(url: branding_profile_params['url']).exists?
      branding_profile = BrandingProfile.create(branding_profile_params.merge(profileable: agency))
      errors.merge!(branding_profile.errors) if branding_profile.errors.present?
      branding_profile
    end

    private

    def update_url
      branding_profile_params['url'] = branding_profile_params['url'] + Time.zone.now.to_i.to_s
    end
  end
end
