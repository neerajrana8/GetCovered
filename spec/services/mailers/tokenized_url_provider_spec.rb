require 'rails_helper'

describe 'Mailers::TokenizedUrlProvider' do
  before :all do
    @user = create_user
    @agency = Agency.find(1)
    @account = FactoryBot.create(:account, agency: @agency)
    @carrier = Carrier.find(1)
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
        policy_type: policy_type,
        status: 'BOUND',
        effective_date: 10.days.ago,
        insurables: [insurable]
      )
    end

    it 'correct url generation' do
      url = Mailers::TokenizedUrlProvider(policy_id: policy.id).call
    end
  end

end
