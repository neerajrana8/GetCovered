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
    carrier = Carrier.find(1)
    # create CAPTs for the new agency, so authorizations & commission strategies exist for Master Policies
    ca = ::CarrierAgency.create!(agency: agency, carrier: carrier, carrier_agency_policy_types_attributes: carrier.carrier_policy_types.map do |cpt|
      {
        policy_type_id: cpt.policy_type_id,
        commission_strategy_attributes: { percentage: 9 }
      }
    end)
    FactoryBot.create(
      :policy,
      :master,
      agency: agency,
      account: account,
      carrier: carrier,
      status: 'BOUND',
      effective_date: Time.zone.now - 2.months,
      expiration_date: Time.zone.now + 2.months,
      number: 'MP',
      insurables: [community1, community2]
    )
  end

  let!(:policy_premium) do
    policy_premium = PolicyPremium.create!(policy: master_policy)
    ppi = ::PolicyPremiumItem.create!(
      policy_premium: policy_premium,
      title: "Per-Coverage Premium",
      category: "premium",
      rounding_error_distribution: "first_payment_simple",
      total_due: 10000,
      proration_calculation: "no_proration",
      proration_refunds_allowed: false,
      commission_calculation: "no_payments",
      recipient: policy_premium.commission_strategy,
      collector: ::Agency.find(1)
    )
    policy_premium.update_totals(persist: true)
  end

  let!(:master_policy_coverage_1) do
    FactoryBot.create(
      :policy,
      :master_coverage,
      agency: agency,
      account: account,
      status: 'BOUND',
      policy: master_policy,
      effective_date: Time.zone.now - 3.months,
      expiration_date: Time.zone.now - 2.months,
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
    pending("Job needs updates")
    expect { BillMasterPoliciesJob.perform_now }.to change { master_policy.master_policy_invoices.count }.by(1)
    expect(master_policy.master_policy_invoices.take.total_due).to eq(30000)
    expect(master_policy.master_policy_invoices.take.line_items.count).to eq(3)
  end

  it 'sends email' do
    pending("Job needs updates")
    expect { BillMasterPoliciesJob.perform_now(true) }.to change { ActionMailer::Base.deliveries.size }.by(1)
  end
end
