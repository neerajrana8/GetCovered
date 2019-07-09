# app/services/commission_service.rb
class CommissionService
  attr_accessor :commission_strategy, :policy_premium
  attr_reader :agency
  
  def initialize(commission_strategy, policy_premium, agency)
    @commission_strategy = commission_strategy
    @policy_premium = policy_premium
    @agency = agency
  end
  
  def process
    case agency
    when 'Get Covered'
      process_get_covered_commission
    else
      process_third_party_commission
    end
  end
  
  def process_get_covered_commission
    account_commission = create_commission(commission_strategy, policy_premium.amount)
    create_deductable_commission(account_commission)
  end


  def calculate_amount(type, premium_amount)
    amount = 0
    case type
    when 'PERCENT'
      amount = (Money.new(premium_amount) * commission_strategy.amount / 100).cents
    when 'FLAT'
      amount = premium_amount
    end
    amount
  end

  def process_third_party_commission
    account_commission = create_commission(commission_strategy, policy_premium.amount)
    agency_commission = create_deductable_commission(account_commission)
    get_covered_strategy = commission_strategy&.commission_strategy&.commission_strategy
    get_covered_commission = create_commission(get_covered_strategy, policy_premium.amount)
  end

  def create_commission(commission_strategy, premium_amount)
    amount = calculate_amount(commission_strategy.type, premium_amount)
    commission = Commission.create(commission_strategy: commission_strategy,
                                   amount: amount)
    commission
  end

  def create_deductable_commission(account_commission)
    parent_commission_strategy = commission_strategy.commission_strategy
    amount = calculate_amount(parent_commission_strategy.type, policy_premium.amount)
    commission = Commission.create do |c|
      c.amount = amount
      c.deduction_amount = account_commission.amount
      c.total = c.amount - c.deduction_amount
    end
    commission
  end


end
