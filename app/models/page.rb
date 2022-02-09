class Page < ApplicationRecord
  include ActionView::Helpers::SanitizeHelper

  belongs_to :agency, optional: true
  belongs_to :branding_profile

  before_create :set_agency
  
  validate :branding_profile_belongs_to_agency,
           unless: proc { |page| page.agency.nil? || page.branding_profile.nil? || page.branding_profile.profileable_type != 'Agency' }

  private
  
  def branding_profile_belongs_to_agency
    errors.add(:branding_profile, 'must be a valid branding profile for the selected agency') unless branding_profile.profileable_id == agency_id
  end

  def set_agency
    if branding_profile.present? && (branding_profile.profileable_type == 'Agency')
      self.agency_id = branding_profile.profileable_id
    end
  end
end
