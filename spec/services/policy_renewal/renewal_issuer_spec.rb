require 'rails_helper'

describe 'PolicyRenewal::RenewalIssuer' do
  before :all do
    @user = create_user
    @agency = Agency.find(1)
    @account = FactoryBot.create(:account, agency: @agency)
    @carrier = Carrier.find(1)
  end

  context 'successfull renewal' do
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

    it 'renew policy with correct statusses' do
      #TBD
      renewal_status = PolicyRenewal::RenewalIssuer.call(policy.number)

    end
  end
  
  context 'failed renewal' do
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

    it 'renew policy with incorrect statusses' do
      #TBD
    end
  end
end
