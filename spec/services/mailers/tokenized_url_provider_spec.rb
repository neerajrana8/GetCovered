require 'rails_helper'

describe 'Mailers::TokenizedUrlProvider' do
  before :all do
    @user = create_user
    FactoryBot.create(:branding_profile, :default_branding_profile)
    @agency = Agency.find(1)
    @account = FactoryBot.create(:account, agency: @agency)
    @carrier = Carrier.find(1)

    @agency_profile = FactoryBot.create(:branding_profile, profileable: @agency, url: 'token_agency.getcovered.com')
  end

  context 'generate renewal url' do
    let(:insurable) { FactoryBot.create(:insurable, :residential_unit) }
    let(:policy_type) { PolicyType.find(PolicyType::RESIDENTIAL_ID) }
    let!(:policy) do
      FactoryBot.create(
        :policy,
        agency: @agency,
        carrier: @carrier,
        account: @account,
        primary_user: @user,
        policy_type: policy_type,
        status: 'BOUND',
        effective_date: 10.days.ago,
        insurables: [insurable]
      )
    end

    it 'correct url generation' do
      url = ::Mailers::TokenizedUrlProvider.new(policy_id: policy.id, branding_profile_id: @agency_profile.id).call
      expect(url).to include("https://token_agency.getcovered.com/user/policies?policy_id=#{policy.id}")
    end
  end

end
