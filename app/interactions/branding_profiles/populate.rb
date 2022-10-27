# Branding Profile
module BrandingProfiles
  # Populate new created branding profile pages and faqs with parent agency data
  class Populate < ActiveInteraction::Base
    object :branding_profile

    def execute
      agency = branding_profile.profileable
      parent_agency = agency.agency
      parent_agency = agency if agency.agency.nil?
      return false unless parent_agency&.branding_profiles&.count&.positive?

      blueprint_bp = parent_agency.branding_profiles.first
      blueprint_bp.pages.each do |page|
        Page.create!(
          title: page.title,
          content: page.content,
          branding_profile_id: branding_profile.id,
          agency_id: agency.id
        )
      end

      blueprint_bp.faqs.each do |f|
        new_faq = Faq.create(
          title: f.title,
          language: f.language,
          branding_profile_id: branding_profile.id,
          faq_order: f.faq_order
        )

        f.faq_questions.each do |fq|
          FaqQuestion.create!(
            faq_id: new_faq.id,
            question: fq.question,
            answer: fq.answer,
            question_order: fq.question_order
          )
        end
      end
    end
  end
end
