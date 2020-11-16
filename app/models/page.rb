class Page < ApplicationRecord
  include ActionView::Helpers::SanitizeHelper

  belongs_to :agency, optional: true
  belongs_to :branding_profile

  before_create :set_agency
  before_save :sanitize_content
  
  validate :branding_profile_belongs_to_agency,
    unless: Proc.new{|page| page.agency.nil? || page.branding_profile.nil? || page.branding_profile.profileable_type != 'Agency' }

  def sanitize_content
    self.content = sanitize content
  end
  
  private
  
  def branding_profile_belongs_to_agency
    errors.add(:branding_profile, "must be a valid branding profile for the selected agency") unless self.branding_profile.profileable_id == self.agency_id
  end

  def set_agency
    if branding_profile.present? && (branding_profile.profileable_type == 'Agency')
      self.agency_id = branding_profile.profileable_id
    end
  end
end
