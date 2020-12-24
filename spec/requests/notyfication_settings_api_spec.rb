require 'rails_helper'
include ActionController::RespondWith

describe 'Notificaton Settings controller spec', type: :request do
  context 'for Users' do
    before :all do
      @user = FactoryBot.create(:user)
    end

    before :each do
      login_user(@user)
      @headers = get_auth_headers_from_login_response_headers(response)
    end

    it 'returns all settings' do
      get('/v2/user/notification_settings', headers: @headers)
      expect(response.status).to eq(200)
      response_json = JSON.parse(response.body)

      expect(response_json.count).to eq(NotificationSetting::USERS_NOTIFICATIONS.count)
    end

    it 'switch a setting' do
      post('/v2/user/notification_settings/switch', headers: @headers, params: { notification_action: :upcoming_invoice })

      expect(response.status).to eq(200)
      response_json = JSON.parse(response.body)

      expect(response_json['success']).to eq(true)

      upcoming_invoice_setting = @user.notification_settings.find_by_action('upcoming_invoice')
      expect(upcoming_invoice_setting.enabled?).to eq(false)
    end
  end
end
