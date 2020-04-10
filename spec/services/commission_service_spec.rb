require 'rails_helper'

describe 'Commission calculation spec', type: :request do
  before(:all) do
    @policy_type = FactoryBot.create(:policy_type)
    @getcovered_agency = FactoryBot.create(:agency)
    @cambridge_agency = FactoryBot.create(:agency, title: "Cambridge")
    @carrier = FactoryBot.create(:carrier)
    @carrier.policy_types << @policy_type
    @carrier.agencies << [@getcovered_agency, @cambridge_agency]
    @getcovered_commission_strategy = FactoryBot.build(:commission_strategy, carrier: @carrier, policy_type: @policy_type, type: 'PERCENT', amount: 30, commissionable: @getcovered_agency)
    @getcovered_commission_strategy.save!
    @cambridge_commission_strategy = FactoryBot.build(:commission_strategy, carrier: @carrier, policy_type: @policy_type, type: 'FLAT', amount: 500)
    @cambridge_commission_strategy.commissionable = @cambridge_agency
    @cambridge_commission_strategy.commission_strategy = @getcovered_commission_strategy
    @cambridge_commission_strategy.save!
    @policy = FactoryBot.build(:policy, agency: @getcovered_agency, carrier: @carrier, account: FactoryBot.create(:account, agency: @getcovered_agency))
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
  end
  
  it 'should create two commissions with proper amounts' do
    # Policy Premium base is $100.00.
    CommissionService.new(@cambridge_commission_strategy, @policy_premium).process
    cambridge_commission = Commission.first
    # Cambridge CommissionStrategy is flat $5. So the commission amount must be 500
    expect(cambridge_commission.amount).to eq(500)

    # GetCovered Commission strategy is 30%, so the commission must be $30
    getcovered_commission = Commission.second
    expect(getcovered_commission.amount).to eq(3000)
    expect(getcovered_commission.deductions).to eq(5)
    expect(getcovered_commission.total).to eq(40)
  end


  it 'should create three commissions with proper amounts' do
    # Policy Premium base is $100.00.
    CommissionService.new(@cambridge_commission_strategy, @policy_premium).process
    cambridge_commission = Commission.first
    # Cambridge CommissionStrategy is flat $5. So the commission amount must be 500
    expect(cambridge_commission.amount).to eq(500)

    # GetCovered Commission strategy is 30%, so the commission must be $30
    getcovered_commission = Commission.second
    expect(getcovered_commission.amount).to eq(3000)
    expect(getcovered_commission.deductions).to eq(5)
    expect(getcovered_commission.total).to eq(40)
  end

    
end