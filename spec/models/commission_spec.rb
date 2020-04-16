# frozen_string_literal: true

RSpec.describe Commission, elasticsearch: true, type: :model do
  before(:all) do
    # This probably needs to be refactored into factories, but I couldn't find a way
    @policy_type = FactoryBot.create(:policy_type)
    @getcovered_agency = FactoryBot.create(:agency)
    @cambridge_agency = FactoryBot.create(:agency, title: "Cambridge")
    @account = FactoryBot.create(:account, agency: @cambridge_agency)
    @carrier = FactoryBot.create(:carrier)
    @carrier.policy_types << @policy_type
    @carrier.agencies << [@getcovered_agency, @cambridge_agency]
    @getcovered_commission_strategy = FactoryBot.build(:commission_strategy, carrier: @carrier, policy_type: @policy_type, type: 'PERCENT', amount: 30, commissionable: @getcovered_agency)
    @getcovered_commission_strategy.save!
    @cambridge_commission_strategy = FactoryBot.build(:commission_strategy, carrier: @carrier, policy_type: @policy_type, type: 'FLAT', amount: 500)
    @cambridge_commission_strategy.commissionable = @cambridge_agency
    @cambridge_commission_strategy.commission_strategy = @getcovered_commission_strategy
    @cambridge_commission_strategy.save!
    @policy = FactoryBot.build(:policy, agency: @cambridge_agency, carrier: @carrier, account: @account)
    @policy.policy_type = @policy_type
    @policy.save!
    @policy_quote = FactoryBot.create(:policy_quote, agency: @getcovered_agency, policy: @policy)
    @billing_strategy = FactoryBot.create(:monthly_billing_strategy, agency: @getcovered_agency, carrier: @carrier, policy_type: @policy_type)
    @policy_premium = FactoryBot.build(:policy_premium, policy_quote: @policy_quote, billing_strategy: @billing_strategy)
    @policy_premium.base = 10000
    @policy_premium.total = @policy_premium.base + @policy_premium.taxes + @policy_premium.total_fees
    @policy_premium.calculation_base = @policy_premium.base + @policy_premium.taxes + @policy_premium.amortized_fees
    @policy_premium.policy = @policy
    @policy_premium.save!
    CommissionService.new(@cambridge_commission_strategy, @policy_premium).process
  end
  it 'should enqueue stripe payout' do
    expect(Commission.count).to eq(2)
    cambridge_commission = Commission.first
    
    ActiveJob::Base.queue_adapter = :test
    expect {
      cambridge_commission.approve
    }.to have_enqueued_job(StripeCommissionPayoutJob)
  end

  it 'should schedule stripe payout' do
    expect(Commission.count).to eq(2)
    cambridge_commission = Commission.first
    date = 1.day.from_now
    cambridge_commission.update_attribute(:distributes, date)
    
    ActiveJob::Base.queue_adapter = :test
    expect {
      cambridge_commission.approve
    }.to have_enqueued_job(StripeCommissionPayoutJob).at(cambridge_commission.distributes.to_datetime)
  end

end
