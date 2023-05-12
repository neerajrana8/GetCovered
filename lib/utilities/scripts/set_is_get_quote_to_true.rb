module Utilities
  module Scripts
    class SetIsGetQuoteToTrue
      EXCEPTION_IDS = [2668] # http://tigris.policyverify.io

      def perform
        BrandingProfile.where.not(id: EXCEPTION_IDS).each do |branding_profile|

          branding_profile.branding_profile_attributes.create(
            name: 'is_get_quote',
            attribute_type: 'boolean',
            value: 'true'
          )
        end
      end
    end
  end
end
