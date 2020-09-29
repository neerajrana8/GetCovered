module Agencies
  class Create < ActiveInteraction::Base
    hash :agency_params, strip: false
    object :parent_agency, class: Agency, default: nil

    def execute
      ActiveRecord::Base.transaction(requires_new: true)  do
        agency = Agency.create(agency_params.merge(agency_id: parent_agency&.id))
        if agency.errors.any?
          errors.merge!(agency.errors)
          return
        end

        branding_profile_outcome = BrandingProfiles::CreateFromDefault.run(agency: agency)
        unless branding_profile_outcome.valid?
          errors.merge!(branding_profile_outcome.errors)
          raise ActiveRecord::Rollback
        end

        agency
      end
    end
  end
end
