require 'rails_helper'

describe 'Commission calculation spec', type: :request do
  before(:all) do
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
    @policy_premium.commission_strategy = @cambridge_commission_strategy
    @policy_premium.base = 10000
    @policy_premium.total = @policy_premium.base + @policy_premium.taxes + @policy_premium.total_fees
    @policy_premium.calculation_base = @policy_premium.base + @policy_premium.taxes + @policy_premium.amortized_fees
    @policy_premium.policy = @policy
    @policy_premium.save!
  end
  
  it 'should create two commissions with proper amounts' do
    # Policy Premium base is $100.00.
    CommissionService.new(@cambridge_commission_strategy, @policy_premium).process
    expect(Commission.count).to eq(2)
    # Cambridge CommissionStrategy is flat $5. So the commission amount must be 500
    cambridge_commission = Commission.where(commissionable: @cambridge_agency).first
    expect(cambridge_commission.amount).to eq(500)
  
    # GetCovered Commission strategy is 30%, so the commission must be $30
    getcovered_commission = Commission.where(commissionable: @getcovered_agency).first
    expect(getcovered_commission.amount).to eq(3000)
  end
  
  
  it 'should create three commissions with proper amounts' do
  
    # Create Account Commission Strategy with 5% fee:
    @account_commission_strategy = FactoryBot.build(:commission_strategy, carrier: @carrier, policy_type: @policy_type, type: 'PERCENT', amount: 7)
    @account_commission_strategy.commissionable = @account
    @account_commission_strategy.commission_strategy = @cambridge_commission_strategy
    @account_commission_strategy.save!    
  
    # Policy Premium base is $100.00.
    CommissionService.new(@account_commission_strategy, @policy_premium).process
    expect(Commission.count).to eq(3)
    # Account CommissionStrategy is 7%. So the commission amount must be 500
    account_commission = Commission.where(commissionable: @account).first
    expect(account_commission.amount).to eq(700)
  
    # Cambridge CommissionStrategy is flat $5. So the commission amount must be 500
    cambridge_commission = Commission.where(commissionable: @cambridge_agency).first
    expect(cambridge_commission.amount).to eq(500)
  
    # GetCovered Commission strategy is 30%, so the commission must be $30
    getcovered_commission = Commission.where(commissionable: @getcovered_agency).first
    expect(getcovered_commission.amount).to eq(3000)
  end
  
  # This would probably need to be refactored into separate test
  it 'should appropriately calculate commission amount after policy cancellation' do
    # Create new CommissionStrategy to create big amount of Deduction:
    new_cambridge_commission_strategy = FactoryBot.build(:commission_strategy, carrier: @carrier, policy_type: @policy_type, type: 'PERCENT', amount: 30)
    new_cambridge_commission_strategy.commissionable = @cambridge_agency
    new_cambridge_commission_strategy.commission_strategy = @getcovered_commission_strategy
    new_cambridge_commission_strategy.save!
    # Run CommissionService to create new Commissions
    CommissionService.new(new_cambridge_commission_strategy, @policy_premium).process
    cambridge_commission = Commission.where(commissionable: @cambridge_agency).first
    expect(cambridge_commission.amount).to eq(3000)

    # If policy is cancelled halfway, then unearned premium should be negative half of premium base
    @policy_premium.unearned_premium = -@policy_premium.base/2
    @policy_premium.save
    @policy.cancel
    
    # should create CommissionDeduction with correct amount:
    # UnearnedBalance = Commission.amount * Premium.unearned_balance / Premium.base
    # = $30 * $50 / $100 = $15
    expect(CommissionDeduction.count).to eq(1)
    expect(CommissionDeduction.last.unearned_balance).to eq(-1500)
    # Deductee should have a negative commission balance:
    expect(@cambridge_agency.reload.commission_balance).to eq(-1500)
    
    # when new policy with new commission strategy is created, it should deduct correct amount
    new_policy = FactoryBot.create(:policy, agency: @cambridge_agency, carrier: @carrier, account: @account, policy_type: @policy_type)
    new_policy_premium = FactoryBot.build(:policy_premium, policy_quote: @policy_quote, billing_strategy: @billing_strategy)
    new_policy_premium.base = 20000
    new_policy_premium.commission_strategy = @cambridge_commission_strategy
    new_policy_premium.total = new_policy_premium.base + new_policy_premium.taxes + new_policy_premium.total_fees
    new_policy_premium.calculation_base = new_policy_premium.base + new_policy_premium.taxes + new_policy_premium.amortized_fees
    new_policy_premium.policy = new_policy
    new_policy_premium.save!
    
    # Policy Premium base is $200.00.
    CommissionService.new(@cambridge_commission_strategy, new_policy_premium).process
    expect(Commission.count).to eq(4)
    # Cambridge CommissionStrategy is flat $5. But because of commission deductions
    # Cambridge commission equals to 0, because total deduction is greater than commission amount
    cambridge_commission = Commission.where(commissionable: @cambridge_agency).last
    expect(cambridge_commission.amount).to eq(0)
    # CommissionService should create a new deduction with amount equal to
    # Cambridge's unearned commission:
    expect(CommissionDeduction.count).to eq(2)
    expect(CommissionDeduction.last.unearned_balance).to eq(500)
    # Deductee balance should be correct:
    # Policy cancellation created a deduction of -$15.
    # New Policy sell created a deduction of +$5.
    # Balance should be -$10
    @cambridge_agency.reload
    expect(@cambridge_agency.commission_balance).to eq(-1000)
    
    # GetCovered Commission strategy is 30% from $200.00, so the commission must be $30
    getcovered_commission = Commission.where(commissionable: @getcovered_agency).last
    expect(getcovered_commission.amount).to eq(6000)
    
    
    # =====Third Policy =====
    # when another new policy with $500 premium is created, it should create commission with correct amount
    new_cambridge_commission_strategy = FactoryBot.build(:commission_strategy, carrier: @carrier, policy_type: @policy_type, type: 'PERCENT', amount: 12)
    new_cambridge_commission_strategy.commissionable = @cambridge_agency
    new_cambridge_commission_strategy.commission_strategy = @getcovered_commission_strategy
    new_cambridge_commission_strategy.save!

    third_policy = FactoryBot.create(:policy, agency: @cambridge_agency, carrier: @carrier, account: @account, policy_type: @policy_type)
    third_policy_premium = FactoryBot.build(:policy_premium, policy_quote: @policy_quote, billing_strategy: @billing_strategy)
    third_policy_premium.base = 50000
    third_policy_premium.commission_strategy = new_cambridge_commission_strategy
    third_policy_premium.total = third_policy_premium.base + third_policy_premium.taxes + third_policy_premium.total_fees
    third_policy_premium.calculation_base = third_policy_premium.base + third_policy_premium.taxes + third_policy_premium.amortized_fees
    third_policy_premium.policy = third_policy
    third_policy_premium.save!
    
    # Policy Premium base is $500.00.
    CommissionService.new(new_cambridge_commission_strategy, third_policy_premium).process
    expect(Commission.count).to eq(6)
    # Cambridge CommissionStrategy is 12%. Commission without deduction should be $60.
    # Cambridge commission balance equals to -$10, so the commission should be $50
    cambridge_commission = Commission.where(commissionable: @cambridge_agency).last
    expect(cambridge_commission.amount).to eq(5000)
    # CommissionService should create a new deduction with amount equal to
    # negative commission balance:
    expect(CommissionDeduction.count).to eq(3)
    expect(CommissionDeduction.last.unearned_balance).to eq(1000)
    # Deductee balance should be zero:
    @cambridge_agency.reload
    expect(@cambridge_agency.commission_balance).to eq(0)
    
    # GetCovered Commission strategy is 30% from $500.00, so the commission must be $150.00
    getcovered_commission = Commission.where(commissionable: @getcovered_agency).last
    expect(getcovered_commission.amount).to eq(15000)
  end
  
end