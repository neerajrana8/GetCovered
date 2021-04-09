module BrandingProfiles
  class Import < ActiveInteraction::Base
    hash :branding_profile_params, strip: false
    object :agency

    def execute
      branding_profile = BrandingProfile.create(branding_profile_params.merge(profileable: agency, uri: uri))
      errors.merge!(branding_profile.errors) if branding_profile.errors.present?
      branding_profile
    end

    private

    def url
      base_uri = Rails.application.credentials.uri[ENV["RAILS_ENV"].to_sym][:client]
      uri = URI(base_uri)
      uri.host = "#{agency.slug}.#{uri.host}"
      uri.host = "#{agency.slug}-#{Time.zone.now.to_i}.#{URI(base_uri).host}" if BrandingProfile.exists?(url: uri.to_s)
      uri.to_s
    end
  end
end
