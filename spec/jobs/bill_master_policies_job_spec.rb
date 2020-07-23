# frozen_string_literal: true

require 'rails_helper'

describe 'BillMasterPoliciesJob' do
  let(:agency)        { FactoryBot.create(:agency) }
  let(:account)       { FactoryBot.create(:account, agency: agency) }
  let(:agent)         { FactoryBot.create(:staff, role: 'agent', organizable: agency) }
  let(:community1)    { FactoryBot.create(:insurable, :residential_community, account: account, staffs: [agent]) }
  let(:community2)    { FactoryBot.create(:insurable, :residential_community, account: account) }
  let(:unit1)    { FactoryBot.create(:insurable, :residential_unit, account: account, insurable: community1) }
  let(:unit2)    { FactoryBot.create(:insurable, :residential_unit, account: account, insurable: community2) }
  let(:unit3)    { FactoryBot.create(:insurable, :residential_unit, account: account, insurable: community1) }
  let(:unit4)    { FactoryBot.create(:insurable, :residential_unit, account: account, insurable: community2) }

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

  let!(:policy_premium) do
    policy_premium = FactoryBot.build(:policy_premium, policy: master_policy)
    policy_premium.base = 10_000
    policy_premium.total = policy_premium.base + policy_premium.taxes + policy_premium.total_fees
    policy_premium.calculation_base = policy_premium.base + policy_premium.taxes + policy_premium.amortized_fees
    policy_premium.save
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
      status: 'CANCELLED',
      policy: master_policy,
      effective_date: Time.zone.now - 2.weeks,
      expiration_date: Time.zone.now - 1.weeks,
      number: 'MPC2',
      insurables: [unit2]
    )
  end

  let!(:master_policy_coverage_3) do
    FactoryBot.create(
      :policy,
      :master_coverage,
      agency: agency,
      account: account,
      status: 'CANCELLED',
      policy: master_policy,
      effective_date: Time.zone.now - 2.months,
      expiration_date: Time.zone.now - 1.weeks,
      number: 'MPC3',
      insurables: [unit3]
    )
  end

  let!(:master_policy_coverage_4) do
    FactoryBot.create(
      :policy,
      :master_coverage,
      agency: agency,
      account: account,
      status: 'BOUND',
      policy: master_policy,
      effective_date: Time.zone.now - 1.weeks,
      expiration_date: Time.zone.now + 2.months,
      number: 'MPC4',
      insurables: [unit4]
    )
  end

  it 'generates invoice' do
    expect { BillMasterPoliciesJob.perform_now }.to change { master_policy.master_policy_invoices.count }.by(1)
    ap master_policy.master_policy_invoices.take
    ap master_policy.master_policy_invoices.take.line_items
  end
end
