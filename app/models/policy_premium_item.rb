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
  has_many :policy_premium_item_terms

  # Callbacks
  before_validation :set_missing_total_data,
    on: :create,
    if: Proc.new{|ppi| ppi.original_total_due.nil? || ppi.total_due.nil? }
  before_validation :set_amortization_plan,
    if: :will_save_change_to_amortization?

  # Validations
  validates_presence_of :title
  validates_presence_of :category
  validates_presence_of :amortization
  validates_presence_of :amortization_plan
  validates_presence_of :rounding_error_distribution
  validates :original_total_due, numericality: { :greater_than_or_equal_to => 0 }
  validates :total_due, numericality: { :greater_than_or_equal_to => 0 }
  validates :total_received, numericality: { :greater_than_or_equal_to => 0 }
  validates :total_processed, numericality: { :greater_than_or_equal_to => 0 }
  validates_presence_of :proration_calculation
  validates_inclusion_of :preprocessed, in: [true, false]
  
  validate :validate_amortization_plan
  
  
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
    custom_spread: 4,
    custom_spread_dollar_amounts: 5
  }, _prefix: false, _suffix: false
  enum rounding_error_distribution: {
    last_payment_simple: 0,       # distributes total by weight rounded down to the nearest cent; dumps remainder on last payment
    first_payment_simple: 1,      # same but dumps on the first payment
    last_payment_multipass: 2,    # distributes total by weight rounded down to the nearest cent; distributes remainder by weight and repeats, until a distribution loop distributes nothing; then dumps remainder on last payment
    first_payment_multipass: 3,   # same but dumps on the first payment
    dynamic_forward: 4,           # distributes by weight in one pass, but keeps track of the amount not yet distributed and distributes that over remaining payments by weight
    dynamic_reverse: 5            # same but last-payment to first-payment
  }, _prefix: true, _suffix: false
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
    to_return = nil
    case self.rounding_error_distribution
      when 'dynamic_forward', 'dynamic_reverse'
        total_left = self.original_total_due
        weight_left = self.amortization_plan.inject(0){|sum,val| sum + val }.to_d
        reversal = (self.rounding_error_distribution == 'dynamic_reverse' ? :reverse : :itself)
        to_return = self.amortization_plan.send(reversal).map do |weight|
          li_total = ((weight / weight_left) * total_left).floor
          total_left -= li_total
          weight_left -= weight
          next li_total == 0 ? nil : LineItem.new(
            policy_premium_item: self, # MOOSE WARNING: make it a term!
            title: self.title,
            original_total_due: li_total,
            total_due: li_total,
            total_received: 0,
            total_processed: 0 # MOOSE WARNING: no more price, no refundability, no category
          )
        end.send(reversal)
      when 'first_payment_simple', 'last_payment_simple'
        total_weight = self.amortization_plan.inject(0){|sum,val| sum + val }.to_d
        multiple_passes = self.rounding_error_distribution.end_with?("multipass")
        to_return = self.amortization_plan.map{|weight| { weight: weight, total: 0 } }
        to_distribute = self.original_total_due
        loop do
          distributed = 0
          to_return.each do |tr|
            li_total = ((weight / total_weight) * to_distribute).floor
            tr[:total] += li_total
            distributed += li_total
          end
          to_distribute -= distributed
          break if distributed == 0 || !multiple_passes
        end
        reversal = (self.rounding_error_distribution.start_with?('first_payment') ? :each : :reverse_each)
        to_return.send(reversal).find{|preli| preli[:total] > 0 }[:total] += to_distribute
        to_return.map! do |preli|
          preli[:total] == 0 ? nil : LineItem.new(
            policy_premium_item: self, # MOOSE WARNING: make it a term!
            title: self.title,
            original_total_due: preli[:total],
            total_due: preli[:total],
            total_received: 0,
            total_processed: 0 # MOOSE WARNING: no more price, no refundability, no category
            
          )
        end
    end
    return to_return
  end
  
  
  private
  
    def set_missing_total_data
      # for convenience, so you don't have to set both on create
      self.total_due = self.original_total_due if self.total_due.nil?
      self.original_total_due = self.total_due if self.original_total_due.nil?
    end
  
    def set_amortization_plan
      self.amortization_plan = case self.amortization
        when 'all_up_front'
          (0...(self.billing_strategy.payments_per_term)).map{|x| x == 0 ? 1 : 0 }
        when 'billing_strategy_spread'
          self.billing_strategy.new_business["payments"].select{|p| p > 0 }
        when 'equal_spread'
          (0...(self.billing_strategy.payments_per_term)).map{|x| 1 }
        when 'equal_spread_except_first'
          (0...(self.billing_strategy.payments_per_term)).map{|x| x == 0 ? 0 : 1 }
        when 'custom_spread'
          self.amortization_plan
        when 'custom_spread_dollar_amounts'
          self.amortization_plan
      end
    end
    
    def validate_amortization_plan
      unless self.amortization_plan.class == ::Array &&
             self.amortization_plan.length == self.billing_strategy.payments_per_term &&
             self.amortization_plan.all?{|x| x.is_a?(::Integer) && x >= 0 } &&
             self.amortization_plan.any?{|x| x != 0 }
        errors.add(:amortization_plan, I18n.t('policy_premium_item_model.amortization_plan_is_invalid'))
      elsif self.amortization == 'custom_spread_dollar_amounts' && self.amortization_plan.inject(0){|sum,v| sum + v } != self.original_total
        errors.add(:amortization_plan, I18n.t('policy_premium_item_model.amortization_plan_sum_invalid'))
      end
    end
end








