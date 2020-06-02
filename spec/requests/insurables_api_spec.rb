require 'rails_helper'
include ActionController::RespondWith

describe 'Insurables API spec', type: :request do
  before :all do
    @agency = FactoryBot.create(:agency)
    @account = FactoryBot.create(:account, agency: @agency)
    @insurable_type = FactoryBot.create(:insurable_type)
    @community = FactoryBot.create(:insurable_type)
    @community_2 = FactoryBot.create(:insurable_type)
    @unit = FactoryBot.create(:insurable_type)
    @unit_2 = FactoryBot.create(:insurable_type)
    @unknown = FactoryBot.create(:insurable_type)
    @building = FactoryBot.create(:insurable_type)
    @staff = create_agent_for @agency
  end
  
  context 'for Admin roles' do
    before :each do
      login_staff(@staff)
      @headers = get_auth_headers_from_login_response_headers(response)
    end
    
    it 'should create Insurable' do
      post '/v2/staff_agency/insurables', params: { insurable: correct_params }, headers: @headers
      result = JSON.parse response.body
      expect(response.status).to eq(201)
      expect(result["id"]).to_not eq(nil)
      expect(Address.last.valid?).to eq(true)
    end
    
    it 'should not raise error with invalid state when creating Insurable' do
      post '/v2/staff_agency/insurables', params: { insurable: wrong_state_params }, headers: @headers
      result = JSON.parse response.body
      expect(response.status).to eq(422)
      expect(result["addresses.state"]).to eq([" is not a valid state"])
      expect(Address.last).to eq(nil)
    end
    
    it 'should not raise error with invalid state when updating Insurable' do
      insurable = Insurable.create(correct_params)
      put "/v2/staff_agency/insurables/#{insurable.id}", params: { insurable: wrong_state_params }, headers: @headers
      result = JSON.parse response.body
      expect(response.status).to eq(422)
      expect(result["addresses.state"]).to eq([" is not a valid state"])
      expect(Address.last.state).to eq(correct_params[:addresses_attributes].first[:state])
    end
    
    it 'should list insurables' do
      create_community @account
      create_community @account
      get "/v2/staff_agency/insurables", headers: @headers
      result = JSON.parse response.body
      expect(result.count).to eq(2)
      expect(response.status).to eq(200)
    end
    
    it 'should filter insurables by insurable_id' do
      community = create_community @account
      create_insurable_for @account, @building, community
      create_insurable_for @account, @building, community
      create_insurable_for @account, @building, community
      expect(community.insurables.count).to eq(3)
      get "/v2/staff_agency/insurables", params: {"filter[insurable_id]" => community.id}, headers: @headers
      result = JSON.parse response.body
      expect(result.count).to eq(3)
      expect(response.status).to eq(200)
      first_building = result.first
      expect(first_building['insurable_type_id']).to eq(@building.id)
      expect(first_building['insurable_id']).to eq(community.id)
    end

    it 'should show building and unit count for community even if zero' do
      community = create_community @account
      get "/v2/staff_agency/insurables/#{community.id}", headers: @headers
      result = JSON.parse response.body
      expect(response.status).to eq(200)
      expect(result['buildings_count']).to eq(0)
      expect(result['units_count']).to eq(0)
    end

    it 'should show proper building and unit count for community' do
      community = create_community @account
      create_insurable_for @account, @building, community
      create_insurable_for @account, @unit, community
      create_insurable_for @account, @building, community

      get "/v2/staff_agency/insurables/#{community.id}", headers: @headers
      result = JSON.parse response.body
      expect(response.status).to eq(200)
      expect(result['buildings_count']).to eq(2)
      expect(result['units_count']).to eq(1)
    end
    
  end
  
  def correct_params
    {
      category: "property", 
      covered: "true", 
      enabled: "true", 
      title: "some new insurable",
      account_id: @account.id,
      insurable_type_id: @insurable_type.id,
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
  
  def wrong_state_params
    {
      category: "property", 
      covered: "true", 
      enabled: "true", 
      title: "some new insurable",
      account_id: @account.id,
      insurable_type_id: @insurable_type.id,
      addresses_attributes: [
        {
          city: "Los Angeles",
          county: "LOS ANGELES",
          state: "AC",
          street_number: "3301",
          street_name: "New Drive"
        }
      ]
    }
  end
  
end 
