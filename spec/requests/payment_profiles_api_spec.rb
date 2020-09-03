require 'rails_helper'
include ActionController::RespondWith

describe 'PaymentProfile API spec', type: :request do
  
  context 'for Users' do
    before :all do
      @user = FactoryBot.create(:user)
    end
    
    before :each do
      login_user(@user)
      @headers = get_auth_headers_from_login_response_headers(response)
    end
    
    def create_profile
      post '/v2/user/payment-profiles', params: { payment_profile: payment_profile_params(payer: @user) }, headers: @headers
    end
    
    it 'should create PaymentProfile' do
      expect(PaymentProfile.count).to eq(0)
      expect { create_profile }.to change { PaymentProfile.count }.by(1)
      expect(PaymentProfile.count).to eq(1)
      result = JSON.parse response.body
      expect(response.status).to eq(201)
      expect(result["id"]).to_not eq(nil)
    end
    
    it 'should list PaymentProfiles' do
      first_profile = FactoryBot.create(:payment_profile, payer: @user)
      second_profile = FactoryBot.create(:payment_profile, payer: @user)
      expect(PaymentProfile.count).to eq(2)
      get "/v2/user/payment-profiles", headers: @headers
      result = JSON.parse response.body
      expect(response.status).to eq(200)
      expect(result.count).to eq(2)
    end
    
    it 'should update PaymentProfile' do
      profile = FactoryBot.create(:payment_profile, payer: @user)
      expect(profile.active).to eq(false)
      put "/v2/user/payment-profiles/#{profile.id}", params: { payment_profile: {active: true } }, headers: @headers
      result = JSON.parse response.body
      expect(response.status).to eq(200)
      expect(result["active"]).to eq(true)
    end
    it 'should set default PaymentProfile' do
      profile = FactoryBot.create(:payment_profile, payer: @user)
      last_profile = FactoryBot.create(:payment_profile, payer: @user, default_profile: true)
      
      expect(last_profile.default_profile).to eq(true)
      put "/v2/user/payment-profiles/#{profile.id}/set_default", headers: @headers
      result = JSON.parse response.body
      expect(response.status).to eq(200)
      expect(result["default_profile"]).to eq(true)
    end
  end
  
  context 'for StaffAccounts' do
    before :all do
      @agency = FactoryBot.create(:agency)
      @staff = create_account_for @agency
    end
    
    before :each do
      login_staff(@staff)
      @headers = get_auth_headers_from_login_response_headers(response)
    end
    
    def create_profile
      post '/v2/staff_account/payment-profiles', params: { payment_profile: payment_profile_params(payer: @staff.organizable) }, headers: @headers
    end
    
    it 'should create PaymentProfile' do
      expect { create_profile }.to change { PaymentProfile.count }.by(1)
      
      expect(PaymentProfile.count).to eq(1)
      result = JSON.parse response.body
      expect(response.status).to eq(201)
      expect(result["id"]).to_not eq(nil)
    end
    
    it 'should list PaymentProfiles' do
      first_profile = FactoryBot.create(:payment_profile, payer: @staff.organizable)
      second_profile = FactoryBot.create(:payment_profile, payer: @staff.organizable)
      expect(PaymentProfile.count).to eq(2)
      get "/v2/staff_account/payment-profiles", headers: @headers
      result = JSON.parse response.body
      expect(response.status).to eq(200)
      expect(result.count).to eq(2)
    end
    
    it 'should update PaymentProfile' do
      profile = FactoryBot.create(:payment_profile, payer: @staff.organizable)
      expect(profile.active).to eq(false)
      put "/v2/staff_account/payment-profiles/#{profile.id}", params: { payment_profile: {active: true } }, headers: @headers
      result = JSON.parse response.body
      expect(response.status).to eq(200)
      expect(result["active"]).to eq(true)
    end
    
    it 'should set default PaymentProfile' do
      profile = FactoryBot.create(:payment_profile, payer: @staff.organizable)
      last_profile = FactoryBot.create(:payment_profile, payer: @staff.organizable, default_profile: true)
      
      expect(last_profile.default_profile).to eq(true)
      put "/v2/staff_account/payment-profiles/#{profile.id}/set_default", headers: @headers
      result = JSON.parse response.body
      expect(response.status).to eq(200)
      expect(result["default_profile"]).to eq(true)
    end
  end
  
  
  def payment_profile_params(attributes = nil)
    attributes.reverse_merge!(
      source: "tok_visa"
    )
  end
end
