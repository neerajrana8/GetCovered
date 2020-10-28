module BrandingProfiles
  class Export < ActiveInteraction::Base
    object :branding_profile

    def execute
      branding_profile_attributes.
        merge(
          branding_profile_attributes_attributes: branding_profile_attributes_attributes,
          pages_attributes: pages_attributes,
          faqs_attributes: faqs_attributes
        )
    end

    private

    def branding_profile_attributes
      branding_profile.attributes.
        except('id', 'created_at', 'updated_at', 'profileable_type', 'profileable_id', 'global_default')
    end

    def branding_profile_attributes_attributes
      branding_profile.
        branding_profile_attributes.
        map do |branding_profile_attribute|
          branding_profile_attribute.attributes.except('id', 'branding_profile_id', 'created_at', 'updated_at')
        end
    end

    def pages_attributes
      branding_profile.
        pages.
        map do |page|
          page.attributes.except('id', 'branding_profile_id', 'created_at', 'updated_at', 'agency_id')
        end
    end

    def faqs_attributes
      branding_profile.
        faqs.
        map do |faq|
          faq.attributes.except('id', 'branding_profile_id', 'created_at', 'updated_at').
            merge(faq_questions_attributes: faq_questions_attributes(faq))
        end
    end

    def faq_questions_attributes(faq)
      faq.
        faq_questions.
        map do |faq|
          faq.attributes.except('id', 'faq_id', 'created_at', 'updated_at')
        end
    end
  end
end
