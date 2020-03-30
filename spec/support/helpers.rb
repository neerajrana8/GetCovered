module Helpers
  # Staff
  def create_agency
    FactoryBot.create(:agency)
  end

  def account_for agency
    FactoryBot.create(:account, agency: agency)
  end

  def create_agent_for(agency = nil)
    FactoryBot.create(:staff, organizable: agency, role: 'agent')
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


  # USER
  def create_user
    FactoryBot.create(:user)
  end

  def login_user(user)
    post user_session_path, params: { email: user.email, password: 'test1234' }.to_json, headers: { 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json' }
  end

end
