require 'rails_helper'
include ActionController::RespondWith

describe 'Insurables API spec', type: :request do
  before :all do
    @agency = FactoryBot.create(:agency)
    @account = FactoryBot.create(:account, agency: @agency)
    @insurable_type = FactoryBot.create(:insurable_type)
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
