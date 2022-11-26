module BrandingProfileAttributes
  class Copy < ActiveInteraction::Base
    include Dry::Monads[:do, :result]
    include ::StandardErrorMethods

    array :branding_profile_attributes_ids
    boolean :force, default: false

    def execute
      branding_profiles.each do |branding_profile|
        yield update(branding_profile)
      end

      Success()
    end

    private

    def branding_profiles
      BrandingProfile.where.not(id: branding_profile_attributes.pluck(:branding_profile_id))
    end

    def update_attributes(branding_profile)
      branding_profile_attributes.each do |branding_profile_attribute|
        yield update(branding_profile, branding_profile_attribute.name, branding_profile_attribute.value)
      end
      Success()
    end

    def branding_profile_attributes
      @branding_profile_attributes ||= BrandingProfileAttribute.where(id: branding_profile_attributes_ids)
    end

    def update_attribute(branding_profile, name, value)
      attribute = branding_profile.branding_profile_attributes.find_by_name(name)

      if attribute.present?
        return Success() unless force

        force_update(attribute, value)
      else
        create_attribute(branding_profile, name, value)
      end
    end

    def force_update(attribute, value)
      attribute.update(value: value)
      if attribute.errors.any?
        Failure(standard_error(:branding_profile_attribute_update_failed, nil, attribute.errors.full_messages))
      else
        Success()
      end
    end

    def create_attribute(branding_profile, name, value)
      attribute =
        BrandingProfileAttribute.create(
          branding_profile: branding_profile,
          name: name,
          value: value
        )
      if attribute.errors.any?
        Failure(standard_error(:branding_profile_attribute_create_failed, nil, attribute.errors.full_messages))
      else
        Success()
      end
    end
  end
end
