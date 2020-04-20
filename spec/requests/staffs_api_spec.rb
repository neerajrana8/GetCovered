require 'rails_helper'
include ActionController::RespondWith

describe 'BrandingProfile API spec', type: :request do
  before :all do
    @agency = FactoryBot.create(:agency)
  end
  
  context 'for Agency role' do
    before :all do
      @staff = create_agent_for @agency
    end
    
    before :each do
      login_staff(@staff)
      @headers = get_auth_headers_from_login_response_headers(response)
    end
    
    it 'should create new Profile without id' do
      put "/v2/staff_agency/staffs/#{@staff.id}", params: { staff: profile_params }, headers: @headers
      result = JSON.parse response.body
      expect(response.status).to eq(200)
      expect(result["profile_attributes"]["first_name"]).to eq(profile_params[:profile_attributes][:first_name])
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
      put "/v2/staff_agency/staffs/#{@staff.id}", params: new_profile_params, headers: @headers
      result = JSON.parse response.body
      expect(response.status).to eq(200)
      expect(result["profile_attributes"]["id"]).to eq(id)
      expect(result["profile_attributes"]["first_name"]).to eq(new_profile_params[:staff][:profile_attributes][:first_name])
    end
    
    it 'should allow owners to de-activate' do
      @staff.update_attribute(:enabled, false)
      owner = create_agent_for(@agency, owner: true)
      login_staff(owner)
      headers = get_auth_headers_from_login_response_headers(response)
      put "/v2/staff_agency/staffs/#{@staff.id}/toggle_enabled", headers: headers
      result = JSON.parse response.body
      expect(@staff.reload.enabled).to eq(true)
    end
    
    it 'should not allow non-owners to de-activate' do
      @staff.update_attribute(:enabled, false)
      non_owner = create_agent_for(@agency, owner: false)
      login_staff(non_owner)
      headers = get_auth_headers_from_login_response_headers(response)
      put "/v2/staff_agency/staffs/#{@staff.id}/toggle_enabled", headers: headers
      result = JSON.parse response.body
      expect(result["success"]).to eq(false)
      expect(@staff.reload.enabled).to eq(false)
    end
    
  end
  
  context 'for Account roles' do
    before :all do
      @staff = create_account_for @agency
    end
    
    before :each do
      login_staff(@staff)
      @headers = get_auth_headers_from_login_response_headers(response)
    end
    
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
    
    it 'should allow owners to de-activate' do
      @staff.update_attribute(:enabled, false)
      owner = FactoryBot.create(:staff, organizable: @staff.organizable, owner: true)
      login_staff(owner)
      headers = get_auth_headers_from_login_response_headers(response)
      put "/v2/staff_account/staffs/#{@staff.id}/toggle_enabled", headers: headers
      result = JSON.parse response.body
      expect(@staff.reload.enabled).to eq(true)
    end
    
    it 'should not allow non-owners to de-activate' do
      @staff.update_attribute(:enabled, false)
      non_owner = FactoryBot.create(:staff, organizable: @staff.organizable, owner: false)
      login_staff(non_owner)
      headers = get_auth_headers_from_login_response_headers(response)
      put "/v2/staff_account/staffs/#{@staff.id}/toggle_enabled", headers: headers
      result = JSON.parse response.body
      expect(result["success"]).to eq(false)
      expect(@staff.reload.enabled).to eq(false)
    end
    
    
  end
  
  context 'for SuperAdmin role' do
    before :all do
      @staff = FactoryBot.create(:staff, role: :super_admin)
    end
    
    before :each do
      login_staff(@staff)
      @headers = get_auth_headers_from_login_response_headers(response)
    end
    
    it 'should create new Profile without id' do
      some_staff = create_agent_for @agency, enabled: false
      expect(some_staff.reload.enabled).to eq(false)
      put "/v2/staff_super_admin/staffs/#{some_staff.id}/toggle_enabled", headers: @headers
      expect(some_staff.reload.enabled).to eq(true)
    end
  end
  
end