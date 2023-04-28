require 'rails_helper'

describe 'PolicyRenewal::RefreshRatesService' do
  before :all do
    @user = create_user
    @agency = Agency.find(1)
    @account = FactoryBot.create(:account, agency: @agency)
    @carrier = Carrier.find(1)
  end

  context 'refresh rates before renewal' do
    let(:community) { FactoryBot.create(:insurable, :residential_community) }
    let(:insurable) { FactoryBot.create(:insurable, :residential_unit, insurable_id: community.id) }
    let(:policy_type) { PolicyType.find(PolicyType::RESIDENTIAL_ID) }
    let!(:policy) do
      FactoryBot.create(
        :policy,
        agency: @agency,
        carrier: @carrier,
        account: @account,
        policy_type: policy_type,
        status: 'BOUND',
        effective_date: 10.days.ago,
        insurables: [insurable]
      )
    end

    xit 'refresh rates if needed' do
      #binding.pry
      #TBD
      renewal_status = PolicyRenewal::RefreshRatesService.call(policy.number)

    end

    xit 'raise exception during refreshing rates' do
      #binding.pry
      #TBD
      renewal_status = PolicyRenewal::RefreshRatesService.call(policy.number)

    end
  end

end


