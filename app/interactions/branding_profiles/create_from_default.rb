module BrandingProfiles
  class CreateFromDefault < ActiveInteraction::Base
    object :agency

    def execute
      ActiveRecord::Base.transaction(requires_new: true) do
        branding_profile_params =
          default_branding_profile.
            attributes.
            except('id', 'created_at', 'updated_at').
            merge(profileable: agency, url: "getcovered-#{agency.id}.com")
        @branding_profile = BrandingProfile.create(branding_profile_params)

        if @branding_profile.errors.any?
          errors[:branding_profile].merge!(@branding_profile.errors)
          return
        end

        create_attributes
        create_pages
        create_faqs

        @branding_profile
      end
    end

    private

    def default_branding_profile
      @default_branding_profile ||=
        BrandingProfile.where(profileable_type: Agency.to_s, profileable_id: Agency::GET_COVERED_ID).take
    end

    def create_attributes
      branding_profile_attributes_params =
        default_branding_profile.branding_profile_attributes.map do |branding_profile_attribute|
          branding_profile_attribute.
            attributes.
            except('id', 'created_at', 'updated_at').
            merge(branding_profile_id: @branding_profile.id)
        end
      branding_profile_attributes = BrandingProfileAttribute.create(branding_profile_attributes_params)
    end

    def create_pages
      pages_params = default_branding_profile.pages.map do |page|
        page.
          attributes.
          except('id', 'created_at', 'updated_at').
          merge(branding_profile_id: @branding_profile.id, agency_id: agency.id)
      end
      pages = Page.create(pages_params)
    end

    def create_faqs
      faqs_params = default_branding_profile.faqs.map do |faq|
        faq.
          attributes.
          except('id', 'created_at', 'updated_at').
          merge(branding_profile_id: @branding_profile.id)
      end
      faqs = Faq.create(faqs_params)
    end
  end
end
