# frozen_string_literal: true

require 'rails_helper'
include ActionController::RespondWith

# The authentication header looks something like this:
# {"access-token"=>"abcd1dMVlvW2BT67xIAS_A", "token-type"=>"Bearer", "client"=>"LSJEVZ7Pq6DX5LXvOWMq1w", "expiry"=>"1519086891", "uid"=>"darnell@konopelski.info"}

describe 'Whether authentication is ocurring properly', type: :request do
  before(:each) do
    @user = FactoryBot.create(:user)
    @staff = create_account_for FactoryBot.create(:agency)
  end
  
  
  context 'for users' do
    it 'authenticates if you are an existing user and you satisfy the password' do
      login_user @user
      result = JSON.parse response.body
      expect(response.has_header?('access-token')).to eq(true)
      expect(result['email']).to eq(@user.email)
    end
    
    it 'should return resource json for valid auth headers' do
      login_user @user
      auth_headers = get_auth_headers_from_login_response_headers(response)
      get v2_user_auth_validate_token_path, headers: auth_headers
      result = JSON.parse response.body
      expect(result['email']).to eq(@user.email)
    end
    
    it 'should not return resource json without valid auth headers' do
      auth_headers = {}
      get v2_user_auth_validate_token_path, headers: auth_headers
      result = JSON.parse response.body
      expect(result['email']).to eq(nil)
    end
    
    it 'should update password with valid token' do
      @user.settings['last_reset_password_base_url'] = 'https://getcoveredllc.com/reset_password'
      @user.save
      @reset_password_token  = @user.send_reset_password_instructions
      params = {
        password: 'new password',
        password_confirmation: 'new password',
        reset_password_token: @reset_password_token
      }
      patch user_password_path, params: params
      result = JSON.parse response.body
      expect(result['success']).to eq(true)
      expect(result['message']).to eq('Your password has been successfully updated.')
    end
  end
  
  context 'for staff' do
    it 'authenticates if you are an existing staff, enabled and you satisfy the password' do
      login_staff @staff
      result = JSON.parse response.body
      expect(response.has_header?('access-token')).to eq(true)
      expect(result['email']).to eq(@staff.email)
    end
    
    it 'should return resource json for valid auth headers' do
      login_staff @staff
      auth_headers = get_auth_headers_from_login_response_headers(response)
      get v2_staff_auth_validate_token_path, headers: auth_headers
      result = JSON.parse response.body
      expect(result['email']).to eq(@staff.email)
    end
    
    it 'should not return resource json without valid auth headers' do
      auth_headers = {}
      get v2_staff_auth_validate_token_path, headers: auth_headers
      result = JSON.parse response.body
      expect(result['email']).to eq(nil)
    end
    
    it 'should update password with valid token' do
      @reset_password_token  = @staff.send_reset_password_instructions
      params = {
        password: 'new password',
        password_confirmation: 'new password',
        reset_password_token: @reset_password_token
      }
      patch staff_password_path, params: params
      result = JSON.parse response.body
      
      expect(result['success']).to eq(true)
      expect(result['message']).to eq('Your password has been successfully updated.')
    end
    
    it 'should not authenticate not enabled and non-owner staff' do
      @staff.update(enabled: false, owner: false)
      login_staff @staff
      
      result = JSON.parse response.body
      expect(response.has_header?('access-token')).to eq(false)
      expect(response.status).to eq(401)
      expect(result['errors']).to eq(["Your account is deactivated"])
    end
    
  end  
  
end
