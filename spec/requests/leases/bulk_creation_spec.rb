require 'rails_helper'
include ActionController::RespondWith

describe 'Leases API spec', type: :request do
  describe 'Bulk Creation' do
    before :all do
      community_type_id = InsurableType::RESIDENTIAL_COMMUNITIES_IDS.first
      unit_type_id = InsurableType::RESIDENTIAL_UNITS_IDS.first

      agency = FactoryBot.create(:agency)
      @account = FactoryBot.create(:account, agency: agency)
      @community = FactoryBot.create(:insurable, insurable_type_id: community_type_id, agency_id: agency.id, account_id: @account.id)
      FactoryBot.rewind_sequences
      FactoryBot.create_list(:insurable, 3,
                             insurable_type_id: unit_type_id,
                             insurable: @community,
                             agency_id: agency.id,
                             account_id: @account.id)
      @agent = create_agent_for agency
      @staff = FactoryBot.create(:staff, organizable: @account, role: 'staff')
    end

    shared_examples 'requests' do
      it 'creates three leases and two users for each lease' do
        file = Rack::Test::UploadedFile.new(file_fixture('leases/bulk_create/good_3.csv'), 'text/csv')
        params = { input_file: file, leases: leases_params }
        post "/v2/#{role_route}/leases/bulk_create", params: params, headers: @headers
        assert_response :success
      end

      it 'returns 422 and the list of bad columns' do
        file = Rack::Test::UploadedFile.new(file_fixture('leases/bulk_create/with_different_bad_rows.csv'), 'text/csv')
        params = { input_file: file, leases: leases_params }
        post "/v2/#{role_route}/leases/bulk_create", params: params, headers: @headers
        body_json = JSON.parse(response.body)
        expect(body_json['error']).to eq('Bad file')
        expect(body_json['content']).to eq(bad_file_messages)
        assert_response :unprocessable_entity
      end
    end

    context 'for the agent role' do
      let(:role_route) { 'staff_agency' }
      let(:leases_params) { { community_insurable_id: @community.id, account_id: @account.id } }

      before :each do
        login_staff(@agent)
        @headers = get_auth_headers_from_login_response_headers(response)
      end

      include_examples 'requests'
    end

    context 'for the account role' do
      let(:role_route) { 'staff_account' }
      let(:leases_params) { { community_insurable_id: @community.id } }

      before :each do
        login_staff(@staff)
        @headers = get_auth_headers_from_login_response_headers(response)
      end

      include_examples 'requests'
    end

    private

    def bad_file_messages
      [
        {
          'message' => 'Next columns in the row 2 should be present: start_date, end_date, status, lease_type, unit, tenant_one_email, tenant_one_first_name, tenant_one_last_name, tenant_one_birthday',
          'row' => 2
        },
        {
          'message' => 'Next columns in the row 3 should be present: tenant_one_email, tenant_one_first_name, tenant_one_last_name, tenant_one_birthday',
          'row' => 3
        },
        {
          'message' => 'Tenant one in the row 4 should be older than 18',
          'row' => 4
        },
        {
          'message' => 'Row 5 contains invalid date',
          'row' => 5
        },
        {
          'message' => 'Tenant two in the row 7 should be older than 18',
          'row' => 7
        },
        {
          'message' => 'Next columns in the row 8 should be present: tenant_two_first_name, tenant_two_last_name',
          'row' => 8
        },
        {
          'message' => 'Row 9 has the incorrect status',
          'row' => 9
        },
        {
          'message' => 'Row 10 has the incorrect lease_type',
          'row' => 10
        },
        {
          'message' => "Unit 6 in the row 11 doesn't exist in the system",
          'row' => 11
        }
      ]
    end
  end
end
