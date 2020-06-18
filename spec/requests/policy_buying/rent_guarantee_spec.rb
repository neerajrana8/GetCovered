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
        expect(policy_application.policy_users.count).to eq(1)
        expect(User.find_by_email('applicant@email.com')).to be_present
        policy_quote_id = response_json['quote']['id']
        primary_user_id = response_json['user']['id']

        # Accept policy application
        post("/v2/policy-quotes/#{policy_quote_id}/accept", params: policy_quotes_accept_params(primary_user_id), headers: headers)
        expect(response.status).to eq(200)
        policy_application.reload

        expect(policy_application.status).to eq('accepted')
        expect(policy_application.users.find_by_email('applicant@email.com')).to be_present
        expect(policy_application.policy_quotes.last.invoices.order(:due_date).first.status).to eq('complete')

        policy = policy_application.policy
        expect(policy).to be_present
        expect(policy.status).to eq('BOUND')
        expect(policy.billing_status).to eq('CURRENT')
        expect(policy.policy_in_system).to eq(true)
        expect(policy.policy_users.count).to eq(1)
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

      it 'a new user with a new co-tenant' do
        params = Helpers::RentGuaranteeFormParamsGenerator.run!(co_tenant: {})
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
        response_body = JSON.parse(response.body)
        policy_application = PolicyApplication.find(policy_application_id)
        expect(policy_application).to be_present
        expect(policy_application.status).to eq('quoted')
        expect(policy_application.policy_users.count).to eq(2)
        expect(policy_application.users.find_by_email('applicant@email.com')).to be_present
        expect(policy_application.users.find_by_email('co-tenant@email.com')).to be_present
        # Accept policy application
        policy_quote_id = response_body['quote']['id']
        primary_user_id = response_body['user']['id']
        post("/v2/policy-quotes/#{policy_quote_id}/accept", params: policy_quotes_accept_params(primary_user_id), headers: headers)
        expect(response.status).to eq(200)
        policy_application.reload

        expect(policy_application.status).to eq('accepted')
        expect(policy_application.users.find_by_email('applicant@email.com')).to be_present
        expect(policy_application.users.find_by_email('co-tenant@email.com')).to be_present
        expect(policy_application.policy_quotes.last.invoices.order(:due_date).first.status).to eq('complete')

        policy = policy_application.policy
        expect(policy).to be_present
        expect(policy.status).to eq('BOUND')
        expect(policy.billing_status).to eq('CURRENT')
        expect(policy.policy_in_system).to eq(true)
        expect(policy.policy_users.count).to eq(2)
      end

      it 'a new user with an existing co-tenant' do
        user = FactoryBot.create(:user)
        params = Helpers::RentGuaranteeFormParamsGenerator.run!(co_tenant: { email: user.email })
        post('/v2/policy-applications', params: params[:create_policy_application], headers: headers)
        expect(response.status).to eq(401)
        expected_body = {
          'error' => 'Address mismatch',
          'message' => 'The mailing address associated with this email is different than the one supplied in the recent request.  To change your address please log in'
        }
        body = JSON.parse(response.body)
        expect(body).to eq(expected_body)
      end
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
  end
end
