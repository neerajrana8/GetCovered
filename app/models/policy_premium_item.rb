class PolicyPremiumItem < ApplicationRecord
  # Associations
  belongs_to :policy_premium  # the policy_premium to which this item applies
  belongs_to :recipient,      # who receives this money (generally a Carrier, Agent, or CommissionStrategy)
    polymorphic: true
  belongs_to :collector,      # which Carrier/Agent actually collects the money from users
    polymorphic: true
  belongs_to :fee,            # what Fee this item corresponds to, if any
    optional: true
    
  has_one :billing_strategy,
    through: :policy_premium
    
  # Validations
  validates_presence_of :title
  validates_presence_of :category
  validates_inclusion_of :amortized, in: [true, false]
  validates_inclusion_of :external, in: [true, false]
  validates_inclusion_of :preprocessed, in: [true, false]
  validates :original_total_due, numericality: { :greater_than_or_equal_to => 0 }
  validates :total_due, numericality: { :greater_than_or_equal_to => 0 }
  validates :total_received, numericality: { :greater_than_or_equal_to => 0 }
  validates :total_processed, numericality: { :greater_than_or_equal_to => 0 }
  
  # Enums
  enum category: {
    fee: 0,
    premium: 1,
    special_premium: 2,
    tax: 3
  }
  enum amortization: {
    all_up_front: 0,
    billing_strategy_spread: 1,
    equal_spread: 2,
    equal_spread_except_first: 3,
    custom_spread: 4
  }, _prefix: false, _suffix: false
  enum rounding_error_distribution: {
    rounding_error_on_last_payment: 0,
    rounding_error_equidistributed: 1
  }
  enum proration_calculation: {
    prorate_per_invoice: 0,
    prorate_total: 1
  }
  
  # Public Class Methods
  def from_fee(fee)
    ::PolicyPremiumItem.new(
      recipient: ###MOOSE WARNING FILL OUT #####,
      fee: fee,
      title: fee.title || "#{(fee.amortized || fee.per_payment) ? "Amortized " : ""} Fee",
      category: "fee",
      amortization: fee.amortized ? 'billing_strategy_spread' : fee.per_payment ? 'equal_spread' : 'all_up_front',
      preprocessed: false, # MOOSE WARNING: when should this be true?
      original_total_due: fee.amount * (fee.per_payment ? PAYMENT_COUNT : 1), # MOOSE WARNING: PAYMENT_COUNT from where???
      #### MOOSE WARNING: this is no good, fees can be percentages ########
    )
  end
  
  # Public Instance Methods
  def schedule_line_items
    to_return = (0...(self.billing_strategy.payments_per_term)).map{|x| [] }
    case self.amortization
      when 'all_up_front'
        to_return[0].push(LineItem.new(
        ))
      when 'billing_strategy_spread'
        #self.billing_strategy.
      when 'equal_spread'
      when 'equal_spread_except_first'
      when 'custom_spread'
    end
    return to_return
  end
end








