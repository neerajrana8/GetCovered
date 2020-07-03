require 'rails_helper'
include ActionController::RespondWith

describe 'Master Policies API spec', type: :request do
  let(:agency)  { FactoryBot.create(:agency) }
  let(:account) { FactoryBot.create(:account, agency: agency) }
  let(:agent)   { FactoryBot.create(:staff, role: 'agent', organizable: agency) }
  let(:community1) { FactoryBot.create(:insurable, :residential_community, account: account) }
  let(:community2) { FactoryBot.create(:insurable, :residential_community, account: account) }
  let(:master_policy) do
    FactoryBot.create(
      :policy,
      :master,
      agency: agency,
      account: account,
      insurables: [community1, community2]
    )
  end

  context 'for agents' do
    before :each do
      login_staff(agent)
      @headers = get_auth_headers_from_login_response_headers(response)
    end

    it 'should return list of included communities' do
      get "/v2/staff_agency/master_policies/#{master_policy.id}/communities",
           headers: @headers.reverse_merge(base_headers)

      expect(response.status).to eq(200)
      response_json = JSON.parse(response.body)
      response_community_titles = response_json.map { |community| community['title'] }
      expect(response_json.count).to eq(2)
      expect(response_community_titles).to match_array(%w[2 1])
    end
  end
end
