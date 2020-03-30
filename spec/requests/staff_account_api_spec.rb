require 'rails_helper'
include ActionController::RespondWith

describe 'Staff Account API spec', type: :request do
  before :all do
    @agency = FactoryBot.create(:agency)
    @staff = create_account_for @agency
  end
  
  before :each do
    login_staff(@staff)
    @headers = get_auth_headers_from_login_response_headers(response)
  end
  
  context 'for Admin roles' do
    it 'should create new Profile without id' do
      put "/v2/staff_account/staffs/#{@staff.id}", params: { staff: profile_params }, headers: @headers
      result = JSON.parse response.body
      expect(response.status).to eq(200)
      expect(result["profile_attributes"]["first_name"]).to eq(profile_params[:profile_attributes][:first_name])
    end

    it 'should not create new Profile for wrong role path' do
      put "/v2/staff_agency/staffs/#{@staff.id}", params: { staff: profile_params }, headers: @headers
      result = JSON.parse response.body
      expect(response.status).to eq(401)
    end

    
    it 'should update Profile if id is provided' do
      @staff.create_profile(profile_params[:profile_attributes])
      id = @staff.profile.id
      new_profile_params = {
        staff: {
          profile_attributes: {
            id: id,
            birth_date: "11/03/1988",
            contact_phone: "1234567",
            first_name: "New name",
            last_name: "New last name"
          }
        }
      }
      put "/v2/staff_account/staffs/#{@staff.id}", params: new_profile_params, headers: @headers
      result = JSON.parse response.body
      expect(response.status).to eq(200)
      expect(result["profile_attributes"]["id"]).to eq(id)
      expect(result["profile_attributes"]["first_name"]).to eq(new_profile_params[:staff][:profile_attributes][:first_name])
    end
    
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
end 
