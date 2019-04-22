# frozen_string_literal: true

require 'rails_helper'
include ActionController::RespondWith

# The authentication header looks something like this:
# {"access-token"=>"abcd1dMVlvW2BT67xIAS_A", "token-type"=>"Bearer", "client"=>"LSJEVZ7Pq6DX5LXvOWMq1w", "expiry"=>"1519086891", "uid"=>"darnell@konopelski.info"}

describe 'Whether authentication is ocurring properly', type: :request do
  before(:each) do
    @super_admin = FactoryBot.create(:super_admin)
    @user = FactoryBot.create(:user)
    @staff = FactoryBot.create(:staff)
  end

  def login_super_admin
    post super_admin_session_path, params: { email: @super_admin.email, password: 'test1234' }.to_json, headers: { 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json' }
  end

  def login_user
    post user_session_path, params: { email: @user.email, password: 'test1234' }.to_json, headers: { 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json' }
  end

  def login_staff
    post staff_session_path, params: { email: @staff.email, password: 'test1234' }.to_json, headers: { 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json' }
  end


  context 'for super admins' do
    it 'authenticates if you are an invited super admin and you satisfy the password' do
      login_super_admin
      result = JSON.parse response.body
      expect(response.has_header?('access-token')).to eq(true)
      expect(result['email']).to eq(@super_admin.email)
    end

    it 'should return resource json for valid auth headers' do
      login_super_admin
      auth_params = get_auth_params_from_login_response_headers(response)
      get v1_utility_auth_validate_token_path, headers: auth_params
      result = JSON.parse response.body
      expect(result['email']).to eq(@super_admin.email)
    end

    it 'should not return resource json without valid auth headers' do
      auth_params = {}
      get v1_utility_auth_validate_token_path, headers: auth_params
      result = JSON.parse response.body
      expect(result['email']).to eq(nil)
    end

    it 'should update password with valid token' do
      @reset_password_token  = @super_admin.send_reset_password_instructions
      params = {
        password: 'new password',
        password_confirmation: 'new password',
        reset_password_token: @reset_password_token
      }
      patch super_admin_password_path, params: params
      result = JSON.parse response.body
      expect(result['status']).to eq('success')
      expect(result['statusText']).to eq('Password has been updated')
    end
  end

  context 'for users' do
    it 'authenticates if you are an existing user and you satisfy the password' do
      login_user
      result = JSON.parse response.body
      expect(response.has_header?('access-token')).to eq(true)
      expect(result['email']).to eq(@user.email)
    end
    
    it 'should return resource json for valid auth headers' do
      login_user
      auth_params = get_auth_params_from_login_response_headers(response)
      get v1_user_auth_validate_token_path, headers: auth_params
      result = JSON.parse response.body
      expect(result['email']).to eq(@user.email)
    end

    it 'should not return resource json without valid auth headers' do
      auth_params = {}
      get v1_user_auth_validate_token_path, headers: auth_params
      result = JSON.parse response.body
      expect(result['email']).to eq(nil)
    end

    it 'should update password with valid token' do
      @reset_password_token  = @user.send_reset_password_instructions
      params = {
        password: 'new password',
        password_confirmation: 'new password',
        reset_password_token: @reset_password_token
      }
      patch user_password_path, params: params
      result = JSON.parse response.body
      expect(result['status']).to eq('success')
      expect(result['statusText']).to eq('Password has been updated')
    end
  end

  context 'for staff' do
    it 'authenticates if you are an existing staff and you satisfy the password' do
      login_staff
      result = JSON.parse response.body
      expect(response.has_header?('access-token')).to eq(true)
      expect(result['email']).to eq(@staff.email)
    end

    it 'should return resource json for valid auth headers' do
      login_staff
      auth_params = get_auth_params_from_login_response_headers(response)
      get v1_account_auth_validate_token_path, headers: auth_params
      result = JSON.parse response.body
      expect(result['email']).to eq(@staff.email)
    end

    it 'should not return resource json without valid auth headers' do
      auth_params = {}
      get v1_account_auth_validate_token_path, headers: auth_params
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
      expect(result['status']).to eq('success')
      expect(result['statusText']).to eq('Password has been updated')
    end

  end

  def get_auth_params_from_login_response_headers(response)
    client = response.headers['client']
    token = response.headers['access-token']
    expiry = response.headers['expiry']
    token_type = response.headers['token-type']
    uid = response.headers['uid']

    auth_params = {
      'access-token' => token,
      'client' => client,
      'uid' => uid,
      'expiry' => expiry,
      'token_type' => token_type
    }
    auth_params
  end
end
