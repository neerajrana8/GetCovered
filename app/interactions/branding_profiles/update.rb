module BrandingProfiles
  class Update < ActiveInteraction::Base
    object :branding_profile
    hash :branding_profile_params, strip: false

    def execute
      ActiveRecord::Base.transaction do
        destroy_dependencies
        update_url if BrandingProfile.exists?(url: branding_profile_params['url'])
        branding_profile.update(branding_profile_params)
        errors.merge!(branding_profile.errors) if branding_profile.errors.any?
        branding_profile
      end
    end

    private

    # For the sake
    def update_url
      branding_profile_params['url'] = branding_profile_params['url'] + Time.zone.now.to_i.to_s
    end

    def destroy_dependencies
      branding_profile.branding_profile_attributes.destroy_all
      branding_profile.pages.destroy_all
      branding_profile.faqs.destroy_all
    end
  end
end
