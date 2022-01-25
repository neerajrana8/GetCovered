module ModelParams
  def agency_params
    {
      title: "GetCovered",
      tos_accepted: true,
      whitelabel: true
    }
  end
  
  def account_params
    {
      enabled: true, 
      title: "New account",
      whitelabel: false
    }
  end
  
  def claim_params(agency)
    user = FactoryBot.create(:user)
    policy = FactoryBot.create(:policy, agency: agency)
    user.policies = [policy]
    user.save
    {
      subject: 'New subject claim',
      type_of_loss: "FIRE",
      claimant_id: user.id,
      claimant_type: "User",
      description: "New claim",
      insurable_id: FactoryBot.create(:insurable).id,
      policy_id: policy.id
    }
  end
  
  def insurable_params(account)
    {
      category: 'property', 
      covered: 'true', 
      enabled: 'true', 
      title: 'some new insurable',
      account_id: account.id,
      insurable_type_id: InsurableType::RESIDENTIAL_UNITS_IDS.first,
      addresses_attributes: [
        {
          city: 'Los Angeles',
          county: 'LOS ANGELES',
          state: 'CA',
          street_number: '3301',
          street_name: 'New Drive'
        }
      ]
    }
  end
  
  def lease_params(account)
    lease_type = LeaseType.first
    insurable = FactoryBot.create(:insurable)
    {
      account_id: account.id,
      lease_type_id: lease_type.id,
      insurable_id: insurable.id,
      start_date: 6.months.ago,
      end_date: 6.months.from_now,
      status: :approved,
      covered: true
    }
  end

  def policy_params(account)
    {
      number: "New policy wiht number: #{SecureRandom.uuid}",
      account_id: account.id,
      agency_id: account.agency.id,
      policy_type_id: PolicyType.first.id,
      carrier_id: Carrier.first.id,
      effective_date: 6.months.ago,
      expiration_date: 6.months.from_now,
      policy_in_system: false
    }
  end
  
  
end
