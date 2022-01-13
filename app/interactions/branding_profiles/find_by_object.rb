module BrandingProfiles
  class FindByObject < ActiveInteraction::Base
    interface :object, default: nil

    def execute
      send(object.class.name.underscore) unless object.nil?
    end

    private

    def agency
      object.branding_profiles.first
    end

    def account
      account_branding_profile = object.branding_profiles.first
      return account_branding_profile if account_branding_profile.present?

      self.class.run!(object: object.agency)
    end

    def insurable
      self.class.run!(object: object.account)
    end

    def policy
      self.class.run!(object: object.account) || self.class.run!(object: object.agency)
    end

    def policy_user
      self.class.run!(object: object.policy) ||
        self.class.run!(object: object.policy_application) ||
        self.class.run!(object: object.user)
    end

    # let's assume that user relates only to one active account. Because of uncertainty,  I recommend to use this method
    # only if other aren't available
    def user
      self.class.run!(object: object.accounts.last)
    end

    def policy_application
      self.class.run!(object: object.account) || self.class.run!(object: object.agency)
    end
  end
end
