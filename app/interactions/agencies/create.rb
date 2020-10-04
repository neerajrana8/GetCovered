module Agencies
  class Create < ActiveInteraction::Base
    hash :agency_params, strip: false
    object :parent_agency, class: Agency, default: nil
    object :creator, class: ActiveRecord::Base, default: nil

    def execute
      ActiveRecord::Base.transaction(requires_new: true) do
        agency = create_agency
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

    private

    def create_agency
      if creator.present?
        agency = Agency.new(agency_params.merge(agency_id: parent_agency&.id))
        agency.save_as(creator)
        agency
      else
        Agency.create(agency_params.merge(agency_id: parent_agency&.id))
      end
    end
  end
end
