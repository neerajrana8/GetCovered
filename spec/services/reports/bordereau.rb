require 'rails_helper'

describe 'Reports::Bordereau' do
  let(:agency)        { FactoryBot.create(:agency , contact_info: { email: 'agency@email.com' }) }
  let(:account)       { FactoryBot.create(:account, agency: agency, contact_info: { email: 'account@email.com' }) }
  let(:community1)    { FactoryBot.create(:insurable, :residential_community, account: account) }
  let(:community2)    { FactoryBot.create(:insurable, :residential_community, account: account) }
  let(:unit1)     { FactoryBot.create(:insurable, :residential_unit, account: account, insurable: community1) }
  let!(:unit2)    { FactoryBot.create(:insurable, :residential_unit, account: account, insurable: community2) }
  let!(:unit3)    { FactoryBot.create(:insurable, :residential_unit, account: account, insurable: community2) }

  let(:tenant) { FactoryBot.create(:user) }
  let(:lease) { FactoryBot.create(:lease, insurable: unit1, status: 'current')}
  let!(:lease_user) { FactoryBot.create(:lease_user, lease: lease, user: tenant, primary: true) }

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
      insurables: [community1]
    )
  end

  let(:master_policy_2) do
    FactoryBot.create(
      :policy,
      :master,
      agency: agency,
      account: account,
      status: 'BOUND',
      effective_date: Time.zone.now - 2.months,
      expiration_date: Time.zone.now + 2.months,
      number: 'MP_2',
      system_data: { landlord_sumplimental: true },
      insurables: [community2]
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

  let!(:master_policy_coverage_2) do
    FactoryBot.create(
      :policy,
      :master_coverage,
      agency: agency,
      account: account,
      status: 'BOUND',
      policy: master_policy_2,
      system_data: { landlord_sumplimental: true },
      effective_date: Time.zone.now - 2.months,
      expiration_date: Time.zone.now + 2.weeks,
      number: 'MP_2_C1',
      insurables: [unit2]
    )
  end

  let!(:policy_coverage_21) { FactoryBot.create(:policy_coverage, designation: 'coverage_c', policy: master_policy_2) }
  let!(:policy_coverage_22) { FactoryBot.create(:policy_coverage, designation: 'liability', policy: master_policy_2) }

  let!(:policy_premium) do
    policy_premium = FactoryBot.build(:policy_premium, policy: master_policy)
    policy_premium.base = 10_000
    policy_premium.total = policy_premium.base + policy_premium.taxes + policy_premium.total_fees
    policy_premium.calculation_base = policy_premium.base + policy_premium.taxes + policy_premium.amortized_fees
    policy_premium.save
  end

  context 'Global report' do
    let(:report) do
      report = Reports::Bordereau.new(range_start: 1.month.ago, range_end: Time.zone.now).generate
      report.tap(&:save)
    end

    it 'creates a new report' do
      expect { report }.to change { Report.all.count }.by(1)
    end

    it 'has the one roe' do
      ap report.data
      expect(report.data['rows'].count).to eq(2)
    end
  end

end
