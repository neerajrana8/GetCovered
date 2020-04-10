# app/services/commission_service.rb
class CommissionService
  attr_accessor :commission_strategy, :policy_premium
  
  def initialize(commission_strategy, policy_premium)
    @commission_strategy = commission_strategy
    @policy_premium = policy_premium
  end
  
  def process
    create_commission(commission_strategy)
    CommissionService.new(commission_strategy.commission_strategy, policy_premium).process if commission_strategy.commission_strategy
  end
  
  def calculate_amount(commission_strategy, premium_amount)
    amount = 0
    case commission_strategy.type
    when 'PERCENT'
      amount = premium_amount * commission_strategy.amount / 100
    when 'FLAT'
      amount = commission_strategy.amount
    end
    amount
  end

  def create_commission(commission_strategy)
    amount = calculate_amount(commission_strategy, policy_premium.base)
    commission = Commission.create do |c|
      c.commission_strategy = commission_strategy
      c.amount = amount
      c.policy_premium = policy_premium
      c.commissionable = commission_strategy.commissionable
    end
    commission
  end

end

# class CommissionService
#   attr_accessor :commission_strategy, :policy_premium
#   attr_reader :agency
  
#   def initialize(commission_strategy, policy_premium, agency)
#     @commission_strategy = commission_strategy
#     @policy_premium = policy_premium
#     @agency = agency
#   end
  
#   def process
#     case agency.title
#     when 'Get Covered'
#       process_get_covered_commission
#     else
#       process_third_party_commission
#     end
#   end
  
#   def process_get_covered_commission
#     account_commission = create_commission(commission_strategy)
#     create_deductable_commission(account_commission)
#   end

#   def calculate_amount(commission_strategy, premium_amount)
#     amount = 0
#     case commission_strategy.type
#     when 'PERCENT'
#       amount = (Money.new(premium_amount) * commission_strategy.amount / 100).cents
#     when 'FLAT'
#       amount = commission_strategy.amount
#     end
#     amount
#   end

#   def process_third_party_commission
#     account_commission = create_commission(commission_strategy)
#     agency_commission = create_deductable_commission(account_commission)
#     get_covered_strategy = commission_strategy&.commission_strategy&.commission_strategy
#     get_covered_commission = create_commission(get_covered_strategy)
#   end

#   def create_commission(commission_strategy)
#     amount = calculate_amount(commission_strategy, policy_premium.total)
#     commission = Commission.create do |c|
#       c.commission_strategy = commission_strategy
#       c.amount = amount
#       c.policy_premium = policy_premium
#       c.commissionable = agency
#     end
#     commission
#   end

#   def create_deductable_commission(account_commission)
#     parent_commission_strategy = commission_strategy.commission_strategy
#     amount = calculate_amount(parent_commission_strategy, policy_premium.total)
#     commission = Commission.create do |c|
#       c.amount = amount
#       c.commission_strategy = parent_commission_strategy
#       c.deductions = account_commission.amount
#       c.total = c.amount - c.deductions
#       c.policy_premium = policy_premium
#       c.commissionable = agency
#     end
#     commission
#   end


# end
