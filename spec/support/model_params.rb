module ModelParams
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
    {
      subject: 'New subject claim',
      type_of_loss: "FIRE",
      claimant_id: user.id,
      claimant_type: "User",
      description: "New claim",
      insurable_id: FactoryBot.create(:insurable).id,
      policy_id: FactoryBot.create(:policy, agency: agency).id
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
  
  
  
end