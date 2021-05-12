require 'rails_helper'

describe 'AutomaticMasterCoveragePolicyIssueJob' do
  let(:agency)        { FactoryBot.create(:agency) }
  let(:account)       { FactoryBot.create(:account, agency: agency) }
  let(:community1)    { FactoryBot.create(:insurable, :residential_community, account: account) }
  let(:community2)    { FactoryBot.create(:insurable, :residential_community, account: account) }
  let(:unit1)     { FactoryBot.create(:insurable, :residential_unit, account: account, insurable: community1, occupied: true) }
  let!(:unit2)    { FactoryBot.create(:insurable, :residential_unit, account: account, insurable: community2, occupied: true) }
  let!(:unit3)    { FactoryBot.create(:insurable, :residential_unit, account: account, insurable: community2, occupied: true) }

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

  let!(:master_policy_coverage_1) do
    FactoryBot.create(
      :policy,
      :master_coverage,
      agency: agency,
      account: account,
      status: 'BOUND',
      policy: master_policy,
      effective_date: Time.zone.now - 2.months,
      expiration_date: Time.zone.now + 2.weeks,
      number: 'MPC1',
      insurables: [unit1]
    )
  end

  let!(:policy_premium) do
    policy_premium = FactoryBot.build(:policy_premium, policy: master_policy)
    policy_premium.base = 10_000
    policy_premium.total = policy_premium.base + policy_premium.taxes + policy_premium.total_fees
    policy_premium.calculation_base = policy_premium.base + policy_premium.taxes + policy_premium.amortized_fees
    policy_premium.save
  end

  it 'covers units in the community2' do
    expect { AutomaticMasterCoveragePolicyIssueJob.perform_now(master_policy.id) }.to change { master_policy.policies.count }.by(2)
  end
end
