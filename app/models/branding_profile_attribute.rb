##
# =Branding Profile Attribute Model
# file: +app/models/branding_profile_attribute.rb+

class BrandingProfileAttribute < ApplicationRecord
  belongs_to :branding_profile
end