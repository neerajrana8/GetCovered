require 'rails_helper'
include ActionController::RespondWith

describe 'Admin Policy spec', type: :request do
  before :all do
    @user = create_user
    @agency = Agency.find(1)
    @account = FactoryBot.create(:account, agency: @agency, contact_info: { "contact_email": "test@test.com" })
    @community = FactoryBot.create(:insurable, account: @account, insurable_type_id: 1)
    @unit = FactoryBot.create(:insurable, account: @account, insurable: @community, insurable_type_id: 4)
    @carrier = Carrier.find(1)
    @policy_type = PolicyType.find(1)
  end

  context 'for StaffAccount roles' do
    before :all do
      @staff = FactoryBot.create(:staff, organizable: @account, role: 'staff')
    end
    before :each do
      login_staff(@staff)
      @headers = get_auth_headers_from_login_response_headers(response)
    end

    it 'should add coverage proof' do
      post '/v2/staff_account/policies/add_coverage_proof', params: { policy: coverage_proof_params }, headers: @headers
      result = JSON.parse response.body
      expect(response.status).to eq(201)
      expect(Policy.last.users.last.email).to eq('yernar.mussin@nitka.com')
    end

    it 'should include policy type title in index' do
      FactoryBot.create(:policy, agency: @agency, carrier: @carrier, account: @account, policy_type: @policy_type)
      get '/v2/staff_account/policies', headers: @headers
      result = JSON.parse response.body
      expect(result.first['policy_type_title']).to eq(@policy_type.title)
    end
    it 'should filter by policy number' do
      # First Request should return 3 policies belonging to @policy_type
      policy = FactoryBot.create(:policy, number: 'n0909', agency: @agency, carrier: @carrier, account: @account, policy_type: @policy_type)
      get '/v2/staff_account/policies', params: { 'filter[number]' => policy.number }, headers: @headers
      result = JSON.parse response.body
      expect(result.count).to eq(1)
      expect(result.first['number']).to eq(policy.number)
      expect(response.status).to eq(200)
    end

    it 'should filter by policy type id' do
      # First Request should return 3 policies belonging to @policy_type
      FactoryBot.create(:policy, agency: @agency, carrier: @carrier, account: @account, policy_type: @policy_type)
      FactoryBot.create(:policy, agency: @agency, carrier: @carrier, account: @account, policy_type: @policy_type)
      FactoryBot.create(:policy, agency: @agency, carrier: @carrier, account: @account, policy_type: @policy_type)
      get '/v2/staff_account/policies', params: { 'filter[policy_type_id]' => @policy_type.id }, headers: @headers
      result = JSON.parse response.body
      expect(result.count).to eq(3)
      result.each do |policy|
        expect(policy['policy_type_id']).to eq(@policy_type.id)
      end
      expect(response.status).to eq(200)

      # Second Request should return 0 policies belonging to non-existent policy_type
      login_staff(@staff)
      @headers = get_auth_headers_from_login_response_headers(response)
      get '/v2/staff_account/policies', params: { 'filter[policy_type_id]' => '20' }, headers: @headers
      result = JSON.parse response.body
      expect(response.status).to eq(200)
      expect(result.count).to eq(0)

      # Third Request should return 1 policy belonging to a new policy_type
      new_policy_type = PolicyType.create(id: PolicyType.maximum(:id).next, title: "New Policy Type")
      CarrierPolicyType.create!(carrier: @carrier, policy_type: new_policy_type, commission_strategy_attributes: { percentage: 20 })
      CarrierAgencyPolicyType.create(carrier_agency: CarrierAgency.where(carrier: @carrier, agency: @agency).take, policy_type: new_policy_type, commission_strategy_attributes: { percentage: 10 })
      FactoryBot.create(:policy, agency: @agency, carrier: @carrier, account: @account, policy_type: new_policy_type)
      login_staff(@staff)
      @headers = get_auth_headers_from_login_response_headers(response)
      get '/v2/staff_account/policies', params: { 'filter[policy_type_id]' => new_policy_type.id }, headers: @headers
      result = JSON.parse response.body
      expect(response.status).to eq(200)
      expect(result.count).to eq(1)
    end

    # it 'should search policies by number' do
    #   pending "#{__FILE__} Needs to be updated after removing elasticsearch tests"
    #   # policy = FactoryBot.create(:policy, number: 'n0101', agency: @agency, carrier: @carrier, account: @account, policy_type: @policy_type)
    #   # sleep 5
    #   # get '/v2/staff_account/policies/search', params: { 'query' => policy.number }, headers: @headers
    #   # result = JSON.parse response.body
    #   # expect(response.status).to eq(200)
    #   # expect(result.count).to eq(1)
    #   # expect(result.first['number']).to eq(policy.number)
    # end
  end

  context 'for StaffAgency roles' do
    before :all do
      @staff = create_agent_for @agency
      @staff.staff_permission.update!(permissions: @staff.staff_permission.permissions.merge({ 'policies.policies' => true }))
    end
    before :each do
      login_staff(@staff)
      @headers = get_auth_headers_from_login_response_headers(response)
    end

    it 'should add coverage proof' do
      post '/v2/staff_agency/policies/add_coverage_proof', params: { policy: coverage_proof_params }, headers: @headers
      result = JSON.parse response.body
      expect(response.status).to eq(201)
      expect(Policy.last.users.last.email).to eq('yernar.mussin@nitka.com')
    end

    it 'should include policy type title in index' do
      FactoryBot.create(:policy, agency: @agency, carrier: @carrier, account: @account, policy_type: @policy_type)
      get '/v2/staff_agency/policies', headers: @headers
      result = JSON.parse response.body
      expect(result.first['policy_type_title']).to eq(@policy_type.title)
    end

    it 'should filter by policy number' do
      # First Request should return 3 policies belonging to @policy_type
      policy = FactoryBot.create(:policy, number: 'n0909', agency: @agency, carrier: @carrier, account: @account, policy_type: @policy_type)
      get '/v2/staff_agency/policies', params: { 'filter[number]' => policy.number }, headers: @headers
      result = JSON.parse response.body
      expect(result.count).to eq(1)
      expect(result.first['number']).to eq(policy.number)
      expect(response.status).to eq(200)
    end

    it 'should filter by policy type id' do
      # First Request should return 3 policies belonging to @policy_type
      FactoryBot.create(:policy, agency: @agency, carrier: @carrier, account: @account, policy_type: @policy_type)
      FactoryBot.create(:policy, agency: @agency, carrier: @carrier, account: @account, policy_type: @policy_type)
      FactoryBot.create(:policy, agency: @agency, carrier: @carrier, account: @account, policy_type: @policy_type)
      get '/v2/staff_agency/policies', params: { 'filter[policy_type_id]' => @policy_type.id }, headers: @headers
      result = JSON.parse response.body
      expect(result.count).to eq(3)
      result.each do |policy|
        expect(policy['policy_type_id']).to eq(@policy_type.id)
      end
      expect(response.status).to eq(200)

      # Second Request should return 0 policies belonging to non-existent policy_type
      login_staff(@staff)
      @headers = get_auth_headers_from_login_response_headers(response)
      get '/v2/staff_agency/policies', params: { 'filter[policy_type_id]' => '20' }, headers: @headers
      result = JSON.parse response.body
      expect(response.status).to eq(200)
      expect(result.count).to eq(0)

      # Third Request should return 1 policy belonging to a new policy_type
      new_policy_type = PolicyType.create(id: PolicyType.maximum(:id).next, title: "New Policy Type")
      CarrierPolicyType.create!(carrier: @carrier, policy_type: new_policy_type, commission_strategy_attributes: { percentage: 20 })
      CarrierAgencyPolicyType.create(carrier_agency: CarrierAgency.where(carrier: @carrier, agency: @agency).take, policy_type: new_policy_type, commission_strategy_attributes: { percentage: 10 })
      FactoryBot.create(:policy, agency: @agency, carrier: @carrier, account: @account, policy_type: new_policy_type)
      login_staff(@staff)
      @headers = get_auth_headers_from_login_response_headers(response)
      get '/v2/staff_agency/policies', params: { 'filter[policy_type_id]' => new_policy_type.id }, headers: @headers
      result = JSON.parse response.body
      expect(response.status).to eq(200)
      expect(result.count).to eq(1)
    end

    # it 'should search policies by number' do
    #   pending "#{__FILE__} Needs to be updated after removing elasticsearch tests"
    #   # policy = FactoryBot.create(:policy, number: 'nagency0101', agency: @agency, carrier: @carrier, account: @account, policy_type: @policy_type)
    #   # sleep 5
    #   # get '/v2/staff_agency/policies/search', params: { 'query' => policy.number }, headers: @headers
    #   # result = JSON.parse response.body
    #   # expect(response.status).to eq(200)
    #   # expect(result.count).to eq(1)
    #   # expect(result.first['number']).to eq(policy.number)
    # end
  end

  def coverage_proof_params
    {
      number: "New policy with number: #{SecureRandom.uuid}",
      account_id: @account.id,
      agency_id: @agency.id,
      policy_type_id: @policy_type.id,
      carrier_id: @carrier.id,
      effective_date: 6.months.ago,
      expiration_date: 6.months.from_now,
      out_of_system_carrier_title: 'Out of system carrier',
      address: 'Some address',
      policy_insurables_attributes: [
        { insurable_id: @unit.id }
      ],
      policy_users_attributes: [
        {
          spouse: false,
          primary: true,
          user_attributes: {
            email: 'yernar.mussin@nitka.com',
            address_attributes: {
              city: 'Louisville',
              country: 'United States',
              state: 'KY',
              street_name: '7111 Jefferson Run Dr',
              street_two: '102',
              zip_code: '40219'
            },
            profile_attributes: {
              birth_date: '1993-04-27',
              contact_phone: '7770556406',
              first_name: 'Yernar',
              gender: 'male',
              last_name: 'Mussin',
              salutation: 'mr'
            }
          }
        }
      ]
    }
  end
end
