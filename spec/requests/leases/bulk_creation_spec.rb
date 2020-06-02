require 'rails_helper'
include ActionController::RespondWith

describe 'Leases API spec', type: :request do
  describe 'Bulk Creation' do
    before :all do
      @agency = FactoryBot.create(:agency)
      @account = FactoryBot.create(:account, agency: @agency)
      @community_type = FactoryBot.create(:insurable_type, id: 1)
      @community = FactoryBot.create(:insurable, insurable_type: @community_type, agency_id: @agency.id, account_id: @account.id)
      @unit_type = FactoryBot.create(:insurable_type, id: 4)
      @unit_1 = FactoryBot.create(:insurable, insurable_type: @unit_type, title: '1', insurable: @community, agency_id: @agency.id, account_id: @account.id)
      @unit_2 = FactoryBot.create(:insurable, insurable_type: @unit_type, title: '2', insurable: @community, agency_id: @agency.id, account_id: @account.id)
      @unit_3 = FactoryBot.create(:insurable, insurable_type: @unit_type, title: '3', insurable: @community, agency_id: @agency.id, account_id: @account.id)
      @staff = create_agent_for @agency
      @lease_type = FactoryBot.create(:lease_type, title: 'Residential')
      @lease_type.insurable_types << @unit_type
    end

    context 'for Agent roles' do
      before :each do
        login_staff(@staff)
        @headers = get_auth_headers_from_login_response_headers(response)
      end

      it 'should create three leases and two users' do
        file = Rack::Test::UploadedFile.new(File.open("#{Rails.root}/spec/files/leases/bulk_create_good.csv"), 'text/csv')
        params = { input_file: file, leases: { community_insurable_id: @community.id, account_id: @account.id } }
        post '/v2/staff_agency/leases/bulk_create', params: params, headers: @headers
        assert_response :success
      end
    end
  end
end
