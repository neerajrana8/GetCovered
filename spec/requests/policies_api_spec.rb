require 'rails_helper'
include ActionController::RespondWith

describe 'Admin Policy spec', type: :request do
  before :all do
    @user = create_user
    @agency = FactoryBot.create(:agency)
    @account = FactoryBot.create(:account, agency: @agency)
    @carrier = Carrier.first
    @policy_type = @carrier.policy_types.take
    @agency = FactoryBot.create(:agency)
    @carrier.agencies << @agency
    @account = FactoryBot.create(:account, agency: @agency)
    BillingStrategy.create(title: "Monthly", slug: nil, enabled: true, new_business: {"payments"=>[8.37, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33], "payments_per_term"=>12, "remainder_added_to_deposit"=>true}, renewal: nil, locked: false, agency: @agency, carrier: @carrier, policy_type: @policy_type, carrier_code: nil)
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
      post '/v2/staff_account/policies/add_coverage_proof', params: { policy: coverage_proof_params, users: [user_params] }, headers: @headers
      result = JSON.parse response.body
      expect(result["message"]).to eq("Policy created")
      expect(Policy.last.users.last.email).to eq('yernar.mussin@nitka.com')
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
      post '/v2/staff_agency/policies/add_coverage_proof', params: { policy: coverage_proof_params, users: [user_params] }, headers: @headers
      result = JSON.parse response.body
      expect(result["message"]).to eq("Policy created")
      expect(Policy.last.users.first).to eq(@user)
      expect(Policy.last.users.last.email).to eq('yernar.mussin@nitka.com')
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
      policy_users_attributes: [
        {
          user_id: @user.id
        }
      ]
    }
  end
  
  def user_params
    {
      email: "yernar.mussin@nitka.com",
      address_attributes: {
        city: "Louisville",
        country: "United States",
        state: "KY",
        street_name: "7111 Jefferson Run Dr",
        street_two: "102",
        zip_code: "40219",
      },
      profile_attributes: {
        birth_date: "1993-04-27",
        contact_phone: "7770556406",
        first_name: "Yernar",
        gender: "male",
        last_name: "Mussin",
        salutation: "mr"
      }
    }
  end
  
end
