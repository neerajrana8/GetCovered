require 'rails_helper'
include ActionController::RespondWith

describe 'Policy buying' do
  describe 'Rent Guarantee Form' do
    before(:context) do
      carrier = Carrier.find(4)
      agency  = FactoryBot.create(:agency)
      carrier.agencies << agency
      FactoryBot.create(:monthly_billing_strategy, agency: agency, carrier: carrier, policy_type_id: 5)
    end

    context 'without logged in user' do
      it 'a new user' do
        # Create policy application
        params = Helpers::RentGuaranteeFormParamsGenerator.run!
        post('/v2/policy-applications', params: params[:create_policy_application], headers: headers)
        expect(response.status).to eq(200)
        response_json = JSON.parse(response.body)
        policy_application_id = response_json['id']
        policy_application = PolicyApplication.find(policy_application_id)

        expect(policy_application).to be_present
        expect(policy_application.status).to eq('in_progress')

        # Update Policy
        put("/v2/policy-applications/#{policy_application_id}", params: params[:update_policy_application], headers: headers)
        expect(response.status).to eq(200)
        response_json      = JSON.parse(response.body)
        policy_application = PolicyApplication.find(policy_application_id)
        expect(policy_application).to be_present
        expect(policy_application.status).to eq('quoted')
        policy_quote_id = response_json['quote']['id']
        primary_user_id = response_json['user']['id']

        # Accept policy application
        post("/v2/policy-quotes/#{policy_quote_id}/accept", params: policy_quotes_accept_params(primary_user_id), headers: headers)
      end

      it 'an existed user' do
        user = FactoryBot.create(:user, :accepted)
        params = Helpers::RentGuaranteeFormParamsGenerator.run!(applicant_email: user.email)

        # Create Policy Application
        post('/v2/policy-applications', params: params[:create_policy_application], headers: headers)
        body = JSON.parse(response.body)
        expect(response.status).to eq(401)
        expected_body = {
          'error' => 'User Account Exists',
          'message' => 'A User has already signed up with this email address.  Please log in to complete your application'
        }
        expect(body).to eq(expected_body)
      end
    end

    context 'with logged in user' do
    end

    def headers
      { 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json' }
    end

    def policy_quotes_accept_params(user_id)
      {
        user: {
          id: user_id,
          source: 'tok_visa'
        }
      }.to_json
    end

    def user_params; end

    def co_tenant_params; end
  end
end
