module ComplianceMethods
  # method for returning a tokenized url for the PMA onboarding flow
  def tokenized_url(user_id, community)
    branding_profile_url = community&.account&.branding_profiles&.take&.url
    str_to_encrypt = "user #{user_id} community #{community.id}" #user 1443 community 10035
    auth_token_for_email = EncryptionService.encrypt(str_to_encrypt)
    return "https://#{branding_profile_url}/pma-tenant-onboarding?token=#{auth_token_for_email}"
  end

  def get_insurable_liability_range(insurable)
    account = insurable.account
    carrier_id = account.agency.providing_carrier_id(PolicyType::RESIDENTIAL_ID, insurable){ |cid| (insurable.get_carrier_status(carrier_id) == :preferred) ? true : nil }
    carrier_policy_type = CarrierPolicyType.where(carrier_id: carrier_id, policy_type_id: PolicyType::RESIDENTIAL_ID).take
    uid = (carrier_id == ::MsiService.carrier_id ? '1005' : carrier_id == ::QbeService.carrier_id ? 'liability' : nil)
    liability_options = ::InsurableRateConfiguration.get_inherited_irc(carrier_policy_type, account, insurable).configuration['coverage_options']&.[](uid)&.[]('options')
    @max_liability = liability_options&.map{|opt| opt['value'].to_i }&.max
    @min_liability = liability_options&.map{|opt| opt['value'].to_i }&.min

    if @min_liability.nil? || @min_liability == 0 || @min_liability == "null"
      @min_liability = 1000000
    end

    if @max_liability.nil? || @max_liability == 0 || @max_liability == "null"
      @max_liability = 30000000
    end
  end
end