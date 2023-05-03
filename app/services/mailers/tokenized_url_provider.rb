# frozen_string_literal: true
module Mailers

  # Tokenized Url Provider - generate url with hash with different functions to be used in mailers

  class TokenizedUrlProvider < ApplicationService

    # for welcome home mailers(prefill pma-onboarding form for lease users): "https://#{branding_profile_url}/#{form_url}?token=#{ERB::Util.url_encode(auth_token_for_email)}"
    # for renewal mailers(sent user to login page & redirect to cancel policy renewal button): /user/policies?policy_id=11929&renewal_token=dXNlciAzNjkxMCBjb21tdW5pdHkgMTAyMDU%3D

    TOKEN_TYPE = {
      'welcome_home_prefill' => 0,
      'renewal_redirect' => 1
    }

    attr_accessor :user
    attr_accessor :community
    attr_accessor :branding_profile
    attr_accessor :policy


    def initialize(user_id: nil, community_id: nil, branding_profile_id: nil, policy_id: nil)
      @user = User.find_by_id(user_id)
      @community = Insurable.find_by_id(community_id)
      @branding_profile = BrandingProfile.find_by_id(branding_profile_id)
      @policy = Policy.find_by_id(policy_id)
    end
    #Mailers::TokenizedUrlProvider.token_types["renewal_redirect"]
    def call(token_type = TOKEN_TYPE['renewal_redirect'], form_url = "pma-tenant-onboarding") # "upload-coverage-proof" available option too
      tokenized_url = case token_type
        when TOKEN_TYPE['renewal_redirect']
          generate_renewal_redirect_token if is_params_valid_for_renewals_mailers?
        when  TOKEN_TYPE['welcome_home_prefill']
          generate_welcome_home_prefill_token(form_url) if is_params_valid_for_welcome_home_mailers?
        else
          raise "Unknown token type. Please check enum token_type of current service for available options."
      end

    end

    private

    def generate_welcome_home_prefill_token(form_url)
      str_to_encrypt = "user #{user.id} community #{community.id}" #user 1443 community 10035
      "https://#{branding_profile.url}/#{form_url}?token=#{encode_token_info(str_to_encrypt)}"
    end

    def generate_renewal_redirect_token
      str_to_encrypt = "policy #{policy.id}"
      "https://#{branding_profile.url}/user/policies?policy_id=#{policy.id}&renewal_token=#{encode_token_info(str_to_encrypt)}"
    end

    def encode_token_info(str_to_encrypt)
      auth_token_for_email = Base64.encode64(str_to_encrypt)
      auth_token_for_email.chomp!
      ERB::Util.url_encode(auth_token_for_email)
    end

    def is_params_valid_for_welcome_home_mailers?
      #TODO: need to move out of logic in separeted set branding profile for mailers service
      set_branding_profile if @branding_profile.blank?
      if user.present? && community.present? && branding_profile.present?
        true
      else
        raise "Not valid params for welcome_home_prefill token generation"
      end
    end

    def is_params_valid_for_renewals_mailers?
      if policy.present?
        true
      else
        raise "Not valid params for renewal_redirect token generation"
      end
    end

    def set_branding_profile
      @branding_profile = community&.account&.branding_profiles.where(default: true)&.take if community.present?
    end

    # ========================= OLD REALISATION ONLY FOR TESTING NOW ======================================
    def tokenized_url(user_id, community, form_url = "pma-tenant-onboarding", branding_profile = nil) #upload-coverage-proof
      branding_profile_url = branding_profile.present? ? branding_profile.url : community&.account&.branding_profiles.where(default: true)&.take&.url
      str_to_encrypt = "user #{user_id} community #{community&.id}" #user 1443 community 10035
      #auth_token_for_email = EncryptionService.encrypt(str_to_encrypt)
      auth_token_for_email = Base64.encode64(str_to_encrypt)
      auth_token_for_email.chomp!
      #return "https://#{branding_profile_url}/#{form_url}?token=#{ERB::Util.url_encode(auth_token_for_email)}"
      return "https://#{branding_profile_url}/#{form_url}?token=#{ERB::Util.url_encode(auth_token_for_email)}"
    end

  end
end


