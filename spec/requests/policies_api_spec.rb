require 'rails_helper'
include ActionController::RespondWith

describe 'Admin Policy spec', type: :request do
  before :all do
    @user = create_user
    @policy_type = FactoryBot.create(:policy_type)
    @agency = FactoryBot.create(:agency)
    @account = FactoryBot.create(:account, agency: @agency)
    @carrier = FactoryBot.create(:carrier)
    @carrier.policy_types << @policy_type
    @carrier.agencies << @agency
    billing_strategy = BillingStrategy.create(title: "Monthly", slug: nil, enabled: true, new_business: {"payments"=>[8.37, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33], "payments_per_term"=>12, "remainder_added_to_deposit"=>true}, renewal: nil, locked: false, agency: @agency, carrier: @carrier, policy_type: @policy_type, carrier_code: nil)
    @agency = FactoryBot.create(:agency)
    @account = FactoryBot.create(:account, agency: @agency)
  end
  
  context 'for StaffAccount roles' do
    before :all do
      @staff = create_account_for @agency
    end
    before :each do
      login_staff(@staff)
      @headers = get_auth_headers_from_login_response_headers(response)
    end
    
    
    it 'should add coverage proof' do
      post '/v2/staff_account/policies/add_coverage_proof', params: { policy: coverage_proof_params }, headers: @headers
      result = JSON.parse response.body
      expect(result["message"]).to eq("Policy created")
    end
  end
  
  context 'for StaffAccount roles' do
    before :all do
      @staff = create_agent_for @agency
    end
    before :each do
      login_staff(@staff)
      @headers = get_auth_headers_from_login_response_headers(response)
    end
    
    
    it 'should add coverage proof' do
      post '/v2/staff_agency/policies/add_coverage_proof', params: { policy: coverage_proof_params }, headers: @headers
      result = JSON.parse response.body
      expect(result["message"]).to eq("Policy created")
      expect(Policy.last.users.first).to eq(@user)
    end
  end
  
  
  def coverage_proof_params
    {
      number: "New policy wiht number: #{SecureRandom.uuid}",
      account_id: @account.id,
      agency_id: @agency.id,
      policy_type_id: @policy_type.id,
      carrier_id: @carrier.id,
      effective_date: 6.months.ago,
      expiration_date: 6.months.from_now,
      out_of_system_carrier_title: 'Out of system carrier',
      address: "Some address",
      content: "This is page content",
      policy_users_attributes: [
        {
          user_id: @user.id
        }
      ]
    }
  end
  
end