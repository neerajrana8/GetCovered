require 'rails_helper'
include ActionController::RespondWith

describe 'Master Policies API spec', type: :request do
  let(:agency)  { FactoryBot.create(:agency) }
  let(:account) { FactoryBot.create(:account, agency: agency) }
  let(:agent)   { FactoryBot.create(:staff, role: 'agent', organizable: agency) }
  let(:staff)   { FactoryBot.create(:staff, role: 'staff', organizable: account) }
  let(:community1) { FactoryBot.create(:insurable, :residential_community, account: account) }
  let(:community2) { FactoryBot.create(:insurable, :residential_community, account: account) }
  let(:community_new) { FactoryBot.create(:insurable, :residential_community, account: account) }
  let(:unit) { FactoryBot.create(:insurable, :residential_unit, account: account, insurable: community1) }

  let(:master_policy) do
    FactoryBot.create(
      :policy,
      :master,
      agency: agency,
      account: account,
      status: 'BOUND',
      number: 'MP',
      effective_date: Time.zone.now - 2.months,
      expiration_date: Time.zone.now + 2.months,
      insurables: [community1, community2]
    )
  end

  context 'for agents' do
    before :each do
      login_staff(agent)
      @headers = get_auth_headers_from_login_response_headers(response)
    end

    it 'returns list of included communities' do
      get "/v2/staff_agency/master-policies/#{master_policy.id}/communities",
          headers: @headers.reverse_merge(base_headers)

      expect(response.status).to eq(200)
      response_json = JSON.parse(response.body)
      response_community_titles = response_json.map { |community| community['title'] }
      expect(response_json.count).to eq(2)
      expect(response_community_titles).to match_array([community1.title, community2.title])
    end

    it 'adds a new community' do
      request = lambda do
        post "/v2/staff_agency/master-policies/#{master_policy.id}/add_insurable",
             params: {
               insurable_id: community_new.id,
               account_id: account.id,
               carrier_id: agency.carriers.take.id
             }.to_json,
             headers: @headers.reverse_merge(base_headers)
      end

      expect { request.call }.to change { master_policy.insurables.communities.count }.by(1)
      expect(master_policy.insurables.communities.count).to eq(3)
      expect(response.status).to eq(200)
    end

    it 'covers a unit' do
      request = lambda do
        post "/v2/staff_agency/master-policies/#{master_policy.id}/cover_unit",
             params: { insurable_id: unit.id }.to_json,
             headers: @headers.reverse_merge(base_headers)
      end

      expect { request.call }.to change { unit.policies.current.count }.by(1)
      expect(response.status).to eq(200)
    end
  end

  context 'for staffs' do
    before :each do
      login_staff(staff)
      @headers = get_auth_headers_from_login_response_headers(response)
    end

    it 'covers a unit' do
      request = lambda do
        post "/v2/staff_account/master-policies/#{master_policy.id}/cover_unit",
             params: { insurable_id: unit.id }.to_json,
             headers: @headers.reverse_merge(base_headers)
      end

      expect { request.call }.to change { unit.policies.current.count }.by(1)
      expect(response.status).to eq(200)
    end
  end
end
