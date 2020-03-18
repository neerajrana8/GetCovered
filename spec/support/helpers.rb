module Helpers
  def create_agency
    @agency = FactoryBot.create(:agency)
  end

  def create_agent_for(agency = nil)
    @staff = FactoryBot.create(:staff, organizable: agency, role: 'agent')
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


end
