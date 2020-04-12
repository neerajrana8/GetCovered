# app/services/commission_service.rb
class CommissionService
  attr_reader :commission_strategy, :policy_premium
  
  def initialize(commission_strategy, policy_premium)
    @commission_strategy = commission_strategy
    @policy_premium = policy_premium
  end
  
  def process
    create_commission(commission_strategy)
    CommissionService.new(commission_strategy.commission_strategy, policy_premium).process if commission_strategy.commission_strategy
  end
  
  def calculate_amount(commission_strategy, premium)
    amount_before_deduction = 0
    base = premium&.base || 0
    commission_balance = commission_strategy&.commissionable&.commission_balance || 0
    return 0 if base <= 0
    
    case commission_strategy.type
    when 'PERCENT'
      amount_before_deduction = base * commission_strategy.amount / 100
    when 'FLAT'
      amount_before_deduction = commission_strategy.amount
    end
    
    return amount_before_deduction if commission_balance == 0

    net_amount = amount_before_deduction + commission_balance
    
    if net_amount < 0
      create_commission_deduction(amount_before_deduction)
      return 0
    else
      create_commission_deduction(-commission_balance)
      return net_amount
    end
  end
  
  def create_commission_deduction(balance)
    policy_premium&.policy&.commission_deductions&.create(
      unearned_balance: balance, 
      deductee: commission_strategy&.commissionable
    )
  end
  
  def create_commission(commission_strategy)
    amount = calculate_amount(commission_strategy, policy_premium)
    commission = Commission.create do |c|
      c.commission_strategy = commission_strategy
      c.amount = amount < 0 ? 0 : amount
      c.policy_premium = policy_premium
      c.commissionable = commission_strategy.commissionable
    end
    commission
  end
  
end