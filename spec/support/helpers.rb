module Helpers
  # Staff
  def create_agency
    FactoryBot.create(:agency)
  end
  
  def account_for agency
    FactoryBot.create(:account, agency: agency)
  end
  
  def create_agent_for(agency = nil, attributes = {})
    attributes.reverse_merge!(
      organizable: agency,
      role: 'agent'
    )
    FactoryBot.create(:staff, attributes)
  end
  
  def create_account_for(agency = nil)
    account = account_for agency
    FactoryBot.create(:staff, organizable: account, role: 'staff')
  end
  
  def login_staff(staff)
    post staff_session_path, params: { email: staff.email, password: 'test1234' }.to_json, headers: { 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json' }
  end
  
  def get_auth_headers_from_login_response_headers(response)
    client = response.headers['client']
    token = response.headers['access-token']
    expiry = response.headers['expiry']
    token_type = response.headers['token-type']
    uid = response.headers['uid']
    
    auth_headers = {
      'access-token' => token,
      'client' => client,
      'uid' => uid,
      'expiry' => expiry,
      'token_type' => token_type
    }
    auth_headers
  end
  
  def profile_params
    {
      profile_attributes: {
        birth_date: "11/03/1988",
        contact_phone: "1234567",
        first_name: "Name",
        last_name: "Last name"
      }
    }
  end
  
  
  
  # USER
  def create_user
    FactoryBot.create(:user)
  end
  
  def login_user(user)
    post user_session_path, params: { email: user.email, password: 'test1234' }.to_json, headers: { 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json' }
  end
  
  # Insurable
  def create_community(account)
    insurable_type = InsurableType.find_or_create_by(id: 1) do |insurable_type|
      insurable_type.title = 'Residential Community'
      insurable_type.category = 'property'
      insurable_type.enabled = true
    end
    Insurable.create(insurable_params(account, insurable_type))
  end
  
  def create_insurable_for(account, insurable_type, insurable = nil)
    Insurable.create insurable_params(account, insurable_type, insurable)
  end
  
  def insurable_params(account, insurable_type, insurable = nil)
    {
      category: "property", 
      covered: "true", 
      enabled: "true", 
      title: "some new insurable with unique id: #{SecureRandom.uuid}",
      account: account,
      insurable: insurable,
      insurable_type: insurable_type,
      addresses_attributes: [
        {
          city: "Los Angeles",
          county: "LOS ANGELES",
          state: "CA",
          street_number: "3301",
          street_name: "New Drive"
        }
      ]
    }
  end
  
  
end
