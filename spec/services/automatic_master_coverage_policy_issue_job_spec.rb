require 'rails_helper'

describe 'AutomaticMasterCoveragePolicyIssueJob' do
  let(:agency)        { FactoryBot.create(:agency) }
  let(:account)       { FactoryBot.create(:account, agency: agency) }
  let(:community1)    { FactoryBot.create(:insurable, :residential_community, account: account) }
  let(:community2)    { FactoryBot.create(:insurable, :residential_community, account: account) }
  let(:unit1)     { FactoryBot.create(:insurable, :residential_unit, account: account, insurable: community1) }
  let!(:unit2)    { FactoryBot.create(:insurable, :residential_unit, account: account, insurable: community2) }
  let!(:unit3)    { FactoryBot.create(:insurable, :residential_unit, account: account, insurable: community2) }

  let(:master_policy) do
    FactoryBot.create(
      :policy,
      :master,
      agency: agency,
      account: account,
      status: 'BOUND',
      effective_date: Time.zone.now - 2.months,
      expiration_date: Time.zone.now + 2.months,
      number: 'MP',
      insurables: [community1, community2]
    )
  end
  
  it 'covers units in the community2' do
    expect { AutomaticMasterCoveragePolicyIssueJob.perform_now(master_policy.id) }.to change { master_policy.policies.count }.by(2)
  end
end
