module BrandingProfiles
  class CreateFromDefault < ActiveInteraction::Base
    object :agency

    def execute
      return nil if default_branding_profile.nil? # If there is no default branding profile, add nothing

      ActiveRecord::Base.transaction(requires_new: true) do
        branding_profile_params =
          default_branding_profile.
            attributes.
            except('id', 'created_at', 'updated_at', 'global_default').
            merge(profileable: agency, url: url)
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

    def url
      base_uri = Rails.application.credentials.uri[ENV["RAILS_ENV"].to_sym][:client]
      uri = URI(base_uri)
      uri.host = "#{agency.slug}.#{uri.host}"
      uri.host = "#{agency.slug}-#{Time.zone.now.to_i}.#{URI(base_uri).host}" if BrandingProfile.exists?(url: uri.to_s)
      uri.to_s
    end

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
      bad_attributes = branding_profile_attributes.select { |attribute| attribute.errors.any? }
      if bad_attributes.any?
        errors[:branding_profile_attributes] = []
        errors[:branding_profile_attributes] << bad_attributes.map(&:errors)
        raise ActiveRecord::Rollback
      end
    end

    def create_pages
      pages_params = default_branding_profile.pages.map do |page|
        page.
          attributes.
          except('id', 'created_at', 'updated_at').
          merge(branding_profile_id: @branding_profile.id, agency_id: agency.id)
      end
      pages = Page.create(pages_params)

      bad_pages = pages.select { |page| page.errors.any? }
      if bad_pages.any?
        errors[:pages] = []
        errors[:pages] << bad_pages.map(&:errors)
        raise ActiveRecord::Rollback
      end
    end

    def create_faqs
      faqs_params = default_branding_profile.faqs.map do |faq|
        faq_params =
          faq.
            attributes.
            except('id', 'created_at', 'updated_at').
            merge(branding_profile_id: @branding_profile.id, faq_questions_attributes: [])
        faq.faq_questions do |faq_question|
          faq_params[:faq_questions_attributes] << faq_question.attributes.slice('question', 'answer')
        end
        faq_params
      end

      faqs = Faq.create(faqs_params)

      bad_faqs = faqs.select { |faq| faq.errors.any? }
      if bad_faqs.any?
        errors[:faqs] = []
        errors[:faqs] << bad_faqs.map(&:errors)
        raise ActiveRecord::Rollback
      end

    end
  end
end
