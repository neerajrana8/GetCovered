require 'rails_helper'

describe 'Commission calculation spec', type: :request do
  before(:each) do
    @policy_type = FactoryBot.create(:policy_type)
    @agency = FactoryBot.create(:agency)
    @carrier = FactoryBot.create(:carrier)
    @carrier.policy_types << @policy_type
    @carrier.agencies << @agency
    @commission_strategy = FactoryBot.build(:commission_strategy)
    @commission_strategy.policy_type = @policy_type
    @commission_strategy.type = 'PERCENT'
    @commission_strategy.amount = 30
    @commission_strategy.carrier = @carrier
    @commission_strategy.commissionable = @agency
    @commission_strategy.save!
    @child_commission_strategy = FactoryBot.build(:commission_strategy)
    @child_commission_strategy.policy_type = @policy_type
    @child_commission_strategy.carrier = @carrier
    @child_commission_strategy.type = 'FLAT'
    @child_commission_strategy.amount = 5
    @child_commission_strategy.commissionable = FactoryBot.create(:account)
    @child_commission_strategy.commission_strategy = @commission_strategy
    @child_commission_strategy.save!
    @policy = FactoryBot.build(:policy)
    @policy.policy_type = @policy_type
    @policy.save!
    @policy_premium = FactoryBot.build(:policy_premium)
    @policy_premium.total = 150
    @policy_premium.policy = @policy
    @policy_premium.save!
  end
  
  it 'should create commission for Get Covered agency' do
    CommissionService.new(@child_commission_strategy, @policy_premium, @agency).process
    first_commission = Commission.first
    expect(first_commission.amount).to eq(5)
    second_commission = Commission.second
    expect(second_commission.amount).to eq(45)
    expect(second_commission.deductions).to eq(5)
    expect(second_commission.total).to eq(40)
  end
  
  # it 'should return error' do
  # end
  
end