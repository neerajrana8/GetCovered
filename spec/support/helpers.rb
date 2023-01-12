module Helpers
  def base_headers
    { 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json' }
  end

  # Staff

  def create_agency
    FactoryBot.create(:agency)
  end

  def account_for(agency)
    FactoryBot.create(:account, agency: agency)
  end

  def create_agent_for(agency = nil, attributes = {})
    staff = FactoryBot.create(:staff, attributes.merge(role: 'agent', organizable: agency).symbolize_keys!)
    # staff.role = 'agent'
    # staff.organizable = agency
    # staff.save
    # staff.staff_roles << FactoryBot.create(:staff_role, :for_agency, staff: staff, organizable: agency, role: 'agent')

    staff
  end

  def create_account_for(agency = nil)
    account = account_for agency
    FactoryBot.create(:staff, organizable: account, role: 'staff')
  end



  def login_staff(staff, password: 'test1234')
    post staff_session_path, params: { email: staff.email, password: password }.to_json, headers: base_headers
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

  def get_external_access_token_headers(agency)
    access_token = FactoryBot.create(:access_token, bearer: agency)
    access_headers = {
        'token-key' => access_token.key,
        'token-secret' => access_token.secret
    }
    access_headers
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

  def login_user(user, password: 'test1234')
    post user_session_path, params: { email: user.email, password: password }.to_json, headers: base_headers
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

  # Super Admin

  def create_super_admin
    FactoryBot.create(:admin)
  end

  # def login_super_admin(admin, password: 'test1234')
  #  post staff_session_path, params: { email: admin.email, password: password }.to_json, headers: base_headers
  #end
end
